/*
 * Meta-Selector Prefetcher Implementation (v4 — sticky greedy + epsilon annealing)
 *
 * Runs Tsetlin, LinUCB, and Stride prefetchers simultaneously.
 * Uses sticky greedy selection on actual prefetch accuracy (PT hit rate).
 * Once a winner is chosen at an accuracy-sample boundary, it "sticks" for
 * the entire sampling window.  Epsilon annealing (50% → 5%) gives both
 * prefetchers balanced training early on, preventing "rich-get-richer."
 *
 * Improvements over v1 (confidence-only):
 *   P4: Outcome-based accuracy tracking with sticky greedy selection
 *   P2: Stride restricted to fallback-only role
 *   P3: Faster EMA adaptation (alpha 0.01 → 0.1)
 *   P5: Context-aware selection via PC-indexed accuracy table
 *
 * v3 fixes over v2 (UCB):
 *   - Replaced per-invocation UCB with per-window sticky greedy selection
 *   - UCB exploration bonus caused ping-pong alternation, destroying accuracy
 *
 * v4 fixes over v3 (rich-get-richer):
 *   - Epsilon annealing: 50% → 5% exploration over 100K invocations
 *   - Hysteresis margin reduced: 10% → 5% (1.1 → 1.05)
 */

#include "meta_selector.h"
#include "champsim.h"

using namespace std;

/* ==========================================================================
 * Constructor
 * ========================================================================== */

MetaSelectorPrefetcher::MetaSelectorPrefetcher(
        const TsetlinMachine::Config& tm_cfg,
        const LinUCB::Config& cb_cfg,
        const std::vector<int32_t>& actions,
        uint32_t pt_size,
        uint32_t pref_degree,
        float epsilon,
        uint8_t high_bw_thresh,
        uint64_t seed,
        std::string type,
        // Tsetlin-specific
        bool tsetlin_enable_dyn_degree,
        const std::vector<int32_t>& tsetlin_dyn_deg_thresh,
        const std::vector<int32_t>& tsetlin_dyn_deg_values,
        const std::vector<int32_t>& tsetlin_dyn_deg_thresh_hbw,
        const std::vector<int32_t>& tsetlin_dyn_deg_values_hbw,
        uint32_t tsetlin_temp_delta_bits,
        uint32_t tsetlin_interaction_bits,
        uint32_t tsetlin_temp_bw_bits,
        uint32_t tsetlin_delta_sig_bits,
        uint32_t tsetlin_freq_bits,
        uint32_t tsetlin_conf_bits,
        float tsetlin_epsilon_init,
        uint64_t tsetlin_warmup_invocations,
        bool tsetlin_featurewise,
        int32_t tsetlin_pooling,
        float tsetlin_tm_weight_lr,
        int32_t tsetlin_encoding,
        uint32_t tsetlin_num_tilings,
        uint32_t tsetlin_tiles_per_tiling,
        // LinUCB-specific
        bool linucb_featurewise,
        int32_t linucb_lcb_pooling,
        float linucb_lcb_weight_lr,
        bool linucb_suppress_gating,
        float linucb_suppress_ratio,
        bool linucb_history_features,
        // Meta-selector-specific
        float meta_conf_alpha,
        float meta_epsilon_init,
        float meta_epsilon_final,
        uint64_t meta_epsilon_anneal_invocations,
        float meta_accuracy_alpha,
        float meta_hysteresis_margin,
        uint32_t meta_sample_interval,
        float meta_ctx_blend)
    : Prefetcher(type)
    , m_tsetlin(nullptr)
    , m_linucb(nullptr)
    , m_stride(nullptr)
    , m_conf_alpha(meta_conf_alpha)
    , m_accuracy_alpha(meta_accuracy_alpha)
    , m_sample_interval(meta_sample_interval)
    , m_sample_counter(0)
    , m_last_winner(-1)
    , m_sticky_winner(SP_TSETLIN)  // default until first accuracy sample
    , m_hysteresis_margin(meta_hysteresis_margin)
    , m_ctx_blend(meta_ctx_blend)
    , m_last_pc(0)
    , m_total_invocations(0)
    , m_rng(seed + 777)
    , m_epsilon_init(meta_epsilon_init)
    , m_epsilon_final(meta_epsilon_final)
    , m_epsilon_anneal_invocations(meta_epsilon_anneal_invocations)
    , m_bw_level(0)
{
    // Initialize EMA trackers
    for (int i = 0; i < SP_COUNT; i++) {
        m_conf_ema[i] = 0.0f;
        m_selected_count[i] = 0;
        m_last_pt_hit[i] = 0;
        m_issued_since_sample[i] = 0;
        m_accuracy_ema[i] = 0.0f;
    }
    memset(&m_stats, 0, sizeof(m_stats));

    // Initialize context table
    for (uint32_t i = 0; i < CTX_TABLE_SIZE; i++) {
        for (int j = 0; j < SP_COUNT; j++) {
            m_ctx_table[i].acc_ema[j] = 0.0f;
        }
        m_ctx_table[i].sample_count = 0;
    }

    // ---- Create Tsetlin sub-prefetcher ----
    TsetlinMachine::Config tm_cfg_copy = tm_cfg;
    tm_cfg_copy.num_actions = (uint32_t)actions.size();
    m_tsetlin = new TsetlinPrefetcher(
        tm_cfg_copy, actions,
        pt_size, pref_degree,
        epsilon, high_bw_thresh,
        seed, "tsetlin",
        tsetlin_enable_dyn_degree,
        tsetlin_dyn_deg_thresh, tsetlin_dyn_deg_values,
        tsetlin_dyn_deg_thresh_hbw, tsetlin_dyn_deg_values_hbw,
        tsetlin_temp_delta_bits, tsetlin_interaction_bits,
        tsetlin_temp_bw_bits, tsetlin_delta_sig_bits,
        tsetlin_freq_bits, tsetlin_conf_bits,
        tsetlin_epsilon_init, tsetlin_warmup_invocations,
        tsetlin_featurewise, tsetlin_pooling,
        tsetlin_tm_weight_lr, tsetlin_encoding,
        tsetlin_num_tilings, tsetlin_tiles_per_tiling);

    // ---- Create LinUCB sub-prefetcher ----
    LinUCB::Config cb_cfg_copy = cb_cfg;
    cb_cfg_copy.num_actions = (uint32_t)actions.size();
    m_linucb = new ContextualBanditPrefetcher(
        cb_cfg_copy, actions,
        pt_size, pref_degree,
        epsilon, high_bw_thresh,
        seed + 1, "linucb",
        tsetlin_enable_dyn_degree,
        tsetlin_dyn_deg_thresh, tsetlin_dyn_deg_values,
        tsetlin_dyn_deg_thresh_hbw, tsetlin_dyn_deg_values_hbw,
        linucb_featurewise, linucb_lcb_pooling,
        linucb_lcb_weight_lr,
        linucb_suppress_gating, linucb_suppress_ratio,
        linucb_history_features);

    // ---- Create Stride sub-prefetcher ----
    m_stride = new StridePrefetcher("stride");

    // Reserve space in buffers to avoid reallocation
    for (int i = 0; i < SP_COUNT; i++) {
        m_buffers[i].reserve(8);
    }
}

MetaSelectorPrefetcher::~MetaSelectorPrefetcher()
{
    delete m_tsetlin;
    delete m_linucb;
    delete m_stride;
}

/* ==========================================================================
 * Accuracy Tracking (P4)
 * ========================================================================== */

uint64_t MetaSelectorPrefetcher::get_sub_pt_hits(int32_t idx) const
{
    switch (idx) {
        case SP_TSETLIN: return m_tsetlin->get_pt_hit_count();
        case SP_LINUCB:  return m_linucb->get_pt_hit_count();
        case SP_STRIDE:  return 0;
        default:         return 0;
    }
}

void MetaSelectorPrefetcher::update_accuracy()
{
    // ---- Compute accuracy delta for each sub-prefetcher ----
    for (int i = 0; i < SP_COUNT; i++) {
        uint64_t cur_hits = get_sub_pt_hits(i);
        uint64_t delta_hits = cur_hits - m_last_pt_hit[i];

        float raw_accuracy;
        if (i == SP_STRIDE) {
            // Stride: use EMA-normalized confidence as synthetic accuracy
            float raw_conf = m_stride->get_last_confidence();
            float denom = m_conf_ema[i] + 1e-6f;
            float norm_conf = (denom > 1e-6f) ? raw_conf / denom : 0.0f;
            raw_accuracy = (norm_conf > 1.0f) ? 1.0f : norm_conf;
        } else {
            float denom = (float)m_issued_since_sample[i];
            raw_accuracy = (denom > 0.0f)
                ? (float)delta_hits / denom
                : 0.0f;
        }

        // EMA update
        if (m_accuracy_ema[i] == 0.0f) {
            m_accuracy_ema[i] = raw_accuracy;
        } else {
            m_accuracy_ema[i] = m_accuracy_alpha * raw_accuracy
                              + (1.0f - m_accuracy_alpha) * m_accuracy_ema[i];
        }

        // Reset for next sampling window
        m_last_pt_hit[i] = cur_hits;
        m_issued_since_sample[i] = 0;
    }

    // ---- Sticky greedy: pick new winner at sample boundary ----
    // Blend global accuracy with context-specific accuracy (P5) for the
    // current PC context.  This gives more precise selection per program region.

    uint32_t ctx_idx = (m_last_pc >> 1) & (CTX_TABLE_SIZE - 1);
    ContextEntry& ctx = m_ctx_table[ctx_idx];

    float blended_acc[SP_COUNT];
    for (int i = 0; i < SP_COUNT; i++) {
        if (i == SP_STRIDE) { blended_acc[i] = 0.0f; continue; }
        blended_acc[i] = m_ctx_blend * ctx.acc_ema[i]
                       + (1.0f - m_ctx_blend) * m_accuracy_ema[i];
        if (blended_acc[i] < 0.0f) blended_acc[i] = 0.0f;
        if (blended_acc[i] > 1.0f) blended_acc[i] = 1.0f;
    }

    float acc_ts = blended_acc[SP_TSETLIN];
    float acc_cb = blended_acc[SP_LINUCB];

    int32_t challenger;
    float   inc_acc, chal_acc;
    if (m_sticky_winner == SP_TSETLIN) {
        inc_acc = acc_ts; chal_acc = acc_cb; challenger = SP_LINUCB;
    } else {
        inc_acc = acc_cb; chal_acc = acc_ts; challenger = SP_TSETLIN;
    }

    // Hysteresis: challenger must beat incumbent by m_hysteresis_margin (e.g. 10%).
    // This prevents flip-flopping when both prefetchers have similar accuracy.
    // Special case: also switch if incumbent has near-zero accuracy (degraded).
    if (chal_acc > inc_acc * m_hysteresis_margin && chal_acc > 0.001f) {
        m_sticky_winner = challenger;
        m_stats.sticky_switches++;
    }
    else if (inc_acc < 0.001f && chal_acc > inc_acc) {
        m_sticky_winner = challenger;
        m_stats.sticky_switches++;
    }

    // ---- Update context table entry (P5) ----
    // Do this AFTER sticky winner selection so the context reflects this
    // window's accuracy for the NEXT sample boundary.
    for (int i = 0; i < SP_COUNT; i++) {
        if (ctx.acc_ema[i] == 0.0f) {
            ctx.acc_ema[i] = m_accuracy_ema[i];
        } else {
            float ctx_alpha = m_accuracy_alpha * 0.5f;
            ctx.acc_ema[i] = ctx_alpha * m_accuracy_ema[i]
                           + (1.0f - ctx_alpha) * ctx.acc_ema[i];
        }
    }
    ctx.sample_count++;
}

/* ==========================================================================
 * Epsilon Annealing
 * ========================================================================== */

float MetaSelectorPrefetcher::current_epsilon() const
{
    if (m_epsilon_anneal_invocations == 0) return m_epsilon_final;
    float progress = (float)m_total_invocations / (float)m_epsilon_anneal_invocations;
    if (progress >= 1.0f) return m_epsilon_final;
    return m_epsilon_init - (m_epsilon_init - m_epsilon_final) * progress;
}

/* ==========================================================================
 * Core Selection Logic (sticky greedy with annealed meta-exploration)
 * ========================================================================== */

int32_t MetaSelectorPrefetcher::select_best_prefetcher()
{
    // ---- Step 0: Check which ML prefetchers have predictions ----
    bool ts_has_pred = !m_buffers[SP_TSETLIN].empty();
    bool cb_has_pred = !m_buffers[SP_LINUCB].empty();
    bool st_has_pred = !m_buffers[SP_STRIDE].empty();

    // ---- Fallback: both ML empty → use Stride ----
    if (!ts_has_pred && !cb_has_pred) {
        m_stats.stride_fallback++;
        if (st_has_pred) {
            return SP_STRIDE;
        }
        m_stats.all_empty++;
        return SP_STRIDE;
    }

    // ---- Single ML has predictions → use it directly ----
    if (ts_has_pred && !cb_has_pred) {
        m_stats.single_ml++;
        return SP_TSETLIN;
    }
    if (!ts_has_pred && cb_has_pred) {
        m_stats.single_ml++;
        return SP_LINUCB;
    }

    // Both ML prefetchers have predictions.

    // ---- Meta-level exploration with epsilon annealing ----
    // Starts at 50% to give both prefetchers balanced training.
    // Linearly decays to 5% over the anneal period.
    std::uniform_real_distribution<float> meta_dist(0.0f, 1.0f);
    if (meta_dist(m_rng) < current_epsilon()) {
        m_stats.meta_explore++;
        std::uniform_int_distribution<int32_t> pick(0, 1);
        return (pick(m_rng) == 0) ? SP_TSETLIN : SP_LINUCB;
    }
    m_stats.meta_greedy++;

    // ---- Sticky greedy: return the current sticky winner ----
    // Ensure the sticky winner actually has predictions.
    // If not (edge case), fall back to the other ML prefetcher.
    if (m_sticky_winner == SP_TSETLIN && ts_has_pred) {
        return SP_TSETLIN;
    }
    if (m_sticky_winner == SP_LINUCB && cb_has_pred) {
        return SP_LINUCB;
    }
    // Sticky winner has no predictions — use the other one
    return ts_has_pred ? SP_TSETLIN : SP_LINUCB;
}

const char* MetaSelectorPrefetcher::sub_pref_name(int32_t idx) const
{
    switch (idx) {
        case SP_TSETLIN: return "tsetlin";
        case SP_LINUCB:  return "linucb";
        case SP_STRIDE:  return "stride";
        default:         return "unknown";
    }
}

/* ==========================================================================
 * Main Prefetch Interface
 * ========================================================================== */

void MetaSelectorPrefetcher::invoke_prefetcher(uint64_t pc, uint64_t address,
                                               uint8_t cache_hit, uint8_t type,
                                               std::vector<uint64_t>& pref_addr)
{
    m_total_invocations++;
    m_last_pc = pc;

    // ---- Periodic accuracy sampling (P4) ----
    m_sample_counter++;
    if (m_sample_counter >= m_sample_interval) {
        update_accuracy();
        m_sample_counter = 0;
    }

    // Clear sub-buffers
    for (int i = 0; i < SP_COUNT; i++) {
        m_buffers[i].clear();
    }

    // ---- Step 1: Snapshot PT sizes before invoke ----
    uint32_t ts_pt_before = m_tsetlin->get_pt_size();
    uint32_t cb_pt_before = m_linucb->get_pt_size();

    // ---- Step 2: Run all three sub-prefetchers ----
    m_tsetlin->invoke_prefetcher(pc, address, cache_hit, type, m_buffers[SP_TSETLIN]);
    m_linucb->invoke_prefetcher(pc, address, cache_hit, type, m_buffers[SP_LINUCB]);
    m_stride->invoke_prefetcher(pc, address, cache_hit, type, m_buffers[SP_STRIDE]);

    // ---- Step 2b: Update confidence EMAs (secondary diagnostic signal) ----
    {
        float raw[SP_COUNT];
        raw[SP_TSETLIN] = m_tsetlin->get_last_confidence();
        raw[SP_LINUCB]  = m_linucb->get_last_confidence();
        raw[SP_STRIDE]  = m_stride->get_last_confidence();
        for (int i = 0; i < SP_COUNT; i++) {
            if (m_conf_ema[i] == 0.0f) {
                m_conf_ema[i] = raw[i];
            } else {
                m_conf_ema[i] = m_conf_alpha * raw[i]
                              + (1.0f - m_conf_alpha) * m_conf_ema[i];
            }
        }
    }

    // ---- Step 3: Select the winner (sticky greedy, P2: Stride fallback) ----
    int32_t winner = select_best_prefetcher();

    // ---- P2.9b: Loser training boost ----
    // During sticky-greedy exploitation, the loser gets zero training because
    // its PT entries are discarded immediately (P3.8).  Without any feedback,
    // the loser's model degrades over time and it can never prove it's
    // improved — even if the underlying algorithm has become better (e.g.,
    // after P2.8c dynamic gating).  The epsilon-exploration mechanism provides
    // only 2.5% training rate per prefetcher, which is often insufficient.
    //
    // Fix: with 10% probability, swap the winner for the loser when both ML
    // prefetchers have predictions.  The loser's predictions are issued,
    // its PT entries survive, and it receives real training feedback.
    // This ~10% boost gives the loser enough samples to maintain its model
    // and potentially prove itself worthy of becoming the new sticky winner.
    {
        bool ts_has = !m_buffers[SP_TSETLIN].empty();
        bool cb_has = !m_buffers[SP_LINUCB].empty();
        if (ts_has && cb_has) {
            std::uniform_real_distribution<float> boost_dist(0.0f, 1.0f);
            if (boost_dist(m_rng) < 0.10f) {
                int32_t loser = (winner == SP_TSETLIN) ? SP_LINUCB : SP_TSETLIN;
                winner = loser;
                m_stats.loser_boost++;
            }
        }
    }

    m_selected_count[winner]++;
    m_last_winner = winner;

    // ---- Step 4: Discard loser PT entries ----
    if (winner != SP_TSETLIN) {
        m_tsetlin->pop_pt_entries(ts_pt_before);
    }
    if (winner != SP_LINUCB) {
        m_linucb->pop_pt_entries(cb_pt_before);
    }

    // ---- Step 5: Output winner's predictions ----
    std::vector<uint64_t>& winner_buf = m_buffers[winner];
    if (!winner_buf.empty()) {
        pref_addr.insert(pref_addr.end(), winner_buf.begin(), winner_buf.end());
        // Track issued count for accuracy computation
        m_issued_since_sample[winner] += (uint64_t)winner_buf.size();
    }
}

/* ==========================================================================
 * Callback Forwarding
 * ========================================================================== */

void MetaSelectorPrefetcher::register_fill(uint64_t address)
{
    m_tsetlin->register_fill(address);
    m_linucb->register_fill(address);
}

void MetaSelectorPrefetcher::register_prefetch_hit(uint64_t address)
{
    m_tsetlin->register_prefetch_hit(address);
    m_linucb->register_prefetch_hit(address);
}

void MetaSelectorPrefetcher::update_bw(uint8_t bw_level)
{
    m_bw_level = bw_level;
    m_tsetlin->update_bw(bw_level);
    m_linucb->update_bw(bw_level);
}

void MetaSelectorPrefetcher::update_ipc(uint8_t ipc)
{
    m_tsetlin->update_ipc(ipc);
    m_linucb->update_ipc(ipc);
}

void MetaSelectorPrefetcher::update_acc(uint32_t acc_level)
{
    m_tsetlin->update_acc(acc_level);
    m_linucb->update_acc(acc_level);
}

/* ==========================================================================
 * Stats & Config Output
 * ========================================================================== */

void MetaSelectorPrefetcher::dump_stats()
{
    cout << endl;
    cout << "========== Meta-Selector Prefetcher Statistics ==========" << endl;
    cout << "meta_total_invocations " << m_total_invocations << endl;

    // Selection distribution
    uint64_t total_selections = 0;
    for (int i = 0; i < SP_COUNT; i++) total_selections += m_selected_count[i];
    for (int i = 0; i < SP_COUNT; i++) {
        float pct = (total_selections > 0)
            ? 100.0f * (float)m_selected_count[i] / (float)total_selections
            : 0.0f;
        cout << "meta_selected_" << sub_pref_name(i)
             << " " << m_selected_count[i]
             << " (" << pct << "%)" << endl;
    }

    // Accuracy EMAs
    for (int i = 0; i < SP_COUNT; i++) {
        cout << "meta_accuracy_ema_" << sub_pref_name(i)
             << " " << m_accuracy_ema[i] << endl;
    }

    // Confidence EMAs
    for (int i = 0; i < SP_COUNT; i++) {
        cout << "meta_conf_ema_" << sub_pref_name(i)
             << " " << m_conf_ema[i] << endl;
    }

    cout << "meta_all_empty " << m_stats.all_empty << endl;
    cout << "meta_stride_fallback " << m_stats.stride_fallback << endl;
    cout << "meta_single_ml " << m_stats.single_ml << endl;
    cout << "meta_explore " << m_stats.meta_explore << endl;
    cout << "meta_greedy " << m_stats.meta_greedy << endl;
    cout << "meta_loser_boost " << m_stats.loser_boost << "  # P2.9b" << endl;
    cout << "meta_sticky_switches " << m_stats.sticky_switches << endl;
    cout << "meta_hysteresis_margin " << m_hysteresis_margin << endl;
    cout << "meta_epsilon_init " << m_epsilon_init << endl;
    cout << "meta_epsilon_final " << m_epsilon_final << endl;
    cout << "meta_epsilon_anneal_invocations " << m_epsilon_anneal_invocations << endl;
    cout << "meta_epsilon_current " << current_epsilon() << endl;
    cout << endl;

    // Dump sub-prefetcher stats
    cout << "--- Tsetlin Sub-Prefetcher Stats ---" << endl;
    m_tsetlin->dump_stats();
    cout << "--- LinUCB Sub-Prefetcher Stats ---" << endl;
    m_linucb->dump_stats();
    cout << "--- Stride Sub-Prefetcher Stats ---" << endl;
    m_stride->dump_stats();
    cout << "========== End Meta-Selector Statistics ==========" << endl;
}

void MetaSelectorPrefetcher::print_config()
{
    cout << "meta_selector_conf_alpha " << m_conf_alpha << endl;
    cout << "meta_selector_epsilon_init " << m_epsilon_init << endl;
    cout << "meta_selector_epsilon_final " << m_epsilon_final << endl;
    cout << "meta_selector_epsilon_anneal_invocations " << m_epsilon_anneal_invocations << endl;
    cout << "meta_selector_accuracy_alpha " << m_accuracy_alpha << endl;
    cout << "meta_selector_hysteresis_margin " << m_hysteresis_margin << endl;
    cout << "meta_selector_sample_interval " << m_sample_interval << endl;
    cout << "meta_selector_ctx_blend " << m_ctx_blend << endl;
    cout << endl;
    cout << "--- Tsetlin Sub-Config ---" << endl;
    m_tsetlin->print_config();
    cout << "--- LinUCB Sub-Config ---" << endl;
    m_linucb->print_config();
    cout << "--- Stride Sub-Config ---" << endl;
    m_stride->print_config();
}
