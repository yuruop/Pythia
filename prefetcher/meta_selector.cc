/*
 * Meta-Selector Prefetcher Implementation
 *
 * Runs Tsetlin, LinUCB, and Stride prefetchers simultaneously.
 * Each invocation: all three predict → confidence computed → winner selected →
 * winner's predictions issued.  All three continue learning regardless.
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
        float meta_epsilon)
    : Prefetcher(type)
    , m_tsetlin(nullptr)
    , m_linucb(nullptr)
    , m_stride(nullptr)
    , m_conf_alpha(meta_conf_alpha)
    , m_total_invocations(0)
    , m_rng(seed + 777)   // distinct seed from sub-prefetchers
    , m_meta_epsilon(meta_epsilon)
    , m_bw_level(0)
{
    // Initialize EMA trackers
    for (int i = 0; i < SP_COUNT; i++) {
        m_conf_ema[i] = 0.0f;
        m_selected_count[i] = 0;
    }
    memset(&m_stats, 0, sizeof(m_stats));

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
        tsetlin_enable_dyn_degree,    // reuse same dyn_degree config
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
 * Core Selection Logic
 * ========================================================================== */

int32_t MetaSelectorPrefetcher::select_best_prefetcher()
{
    // ---- Meta-level exploration (P3: prevents training starvation) ----
    // Non-winning prefetchers never get their predictions issued, so their PT
    // entries accumulate negative (unfilled) rewards.  Over time this creates
    // a "rich get richer" dynamic.  Meta-level epsilon-greedy ensures each
    // prefetcher gets occasional training opportunities.
    std::uniform_real_distribution<float> meta_dist(0.0f, 1.0f);
    if (meta_dist(m_rng) < m_meta_epsilon) {
        m_stats.meta_explore++;
        // Pick uniformly among all three to give each a fair shot
        std::uniform_int_distribution<int32_t> pick(0, SP_COUNT - 1);
        int32_t probe = pick(m_rng);
        // Still update EMAs so the confidence tracker stays current
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
        return probe;
    }
    m_stats.meta_exploit++;

    // ---- Confidence-based selection ----
    // Gather raw confidence from each sub-prefetcher
    float raw_conf[SP_COUNT];
    raw_conf[SP_TSETLIN] = m_tsetlin->get_last_confidence();
    raw_conf[SP_LINUCB]  = m_linucb->get_last_confidence();
    raw_conf[SP_STRIDE]  = m_stride->get_last_confidence();

    // Update EMA for each (warm-start: first sample sets the EMA)
    for (int i = 0; i < SP_COUNT; i++) {
        if (m_conf_ema[i] == 0.0f) {
            // First sample: bootstrap EMA with this value
            m_conf_ema[i] = raw_conf[i];
        } else {
            // Standard EMA: slow decay toward current value
            m_conf_ema[i] = m_conf_alpha * raw_conf[i]
                          + (1.0f - m_conf_alpha) * m_conf_ema[i];
        }
    }

    // Normalize each confidence by its own EMA (self-calibrating).
    // A prefetcher is "confident" when its current confidence exceeds its
    // historical average.
    float norm_conf[SP_COUNT];
    for (int i = 0; i < SP_COUNT; i++) {
        float denom = m_conf_ema[i] + 1e-6f;
        norm_conf[i] = raw_conf[i] / denom;
    }

    // Pick the prefetcher with the highest normalized confidence.
    // In the degenerate case where all confidences are ~0 (cold start),
    // all norm_conf values will be ~0 and the fallback chooses the one
    // that actually has predictions in its buffer (checked by caller).
    int32_t best = SP_STRIDE;
    float best_score = norm_conf[SP_STRIDE];

    if (norm_conf[SP_TSETLIN] > best_score) {
        best = SP_TSETLIN;
        best_score = norm_conf[SP_TSETLIN];
    }
    if (norm_conf[SP_LINUCB] > best_score) {
        best = SP_LINUCB;
        best_score = norm_conf[SP_LINUCB];
    }

    // If all three produced effectively zero confidence, fall back to picking
    // one that actually generated predictions, preferring Tsetlin > LinUCB > Stride
    // (Tsetlin and LinUCB have exploration that may produce useful probes).
    if (best_score < 1e-6f) {
        // Try Tsetlin first (has epsilon-greedy exploration)
        if (!m_buffers[SP_TSETLIN].empty()) {
            best = SP_TSETLIN;
        } else if (!m_buffers[SP_LINUCB].empty()) {
            best = SP_LINUCB;
        } else {
            best = SP_STRIDE;  // Stride is always safe (conservative)
        }
    }

    return best;
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

    // Clear sub-buffers
    for (int i = 0; i < SP_COUNT; i++) {
        m_buffers[i].clear();
    }

    // ---- Step 1: Run all three sub-prefetchers ----
    // Each updates its internal state (PT, learning, tracker tables) and
    // fills its own prediction buffer.
    m_tsetlin->invoke_prefetcher(pc, address, cache_hit, type, m_buffers[SP_TSETLIN]);
    m_linucb->invoke_prefetcher(pc, address, cache_hit, type, m_buffers[SP_LINUCB]);
    m_stride->invoke_prefetcher(pc, address, cache_hit, type, m_buffers[SP_STRIDE]);

    // ---- Step 2: Compute confidence and select the winner ----
    int32_t winner = select_best_prefetcher();
    m_selected_count[winner]++;

    // ---- Step 3: Output winner's predictions ----
    std::vector<uint64_t>& winner_buf = m_buffers[winner];
    if (!winner_buf.empty()) {
        pref_addr.insert(pref_addr.end(), winner_buf.begin(), winner_buf.end());
    }

    // Track degenerate case: all three produced empty predictions
    {
        bool all_empty = true;
        for (int i = 0; i < SP_COUNT; i++) {
            if (!m_buffers[i].empty()) { all_empty = false; break; }
        }
        if (all_empty) {
            m_stats.all_empty++;
        }
    }
}

/* ==========================================================================
 * Callback Forwarding
 * ========================================================================== */

void MetaSelectorPrefetcher::register_fill(uint64_t address)
{
    // Forward to all sub-prefetchers. Each handles its own PT entries —
    // entries from non-winning sub-prefetchers will time out as "unfilled",
    // providing a mild corrective signal.
    m_tsetlin->register_fill(address);
    m_linucb->register_fill(address);
    // Stride prefetcher doesn't have register_fill (PT-less design)
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

    // Confidence EMA values
    for (int i = 0; i < SP_COUNT; i++) {
        cout << "meta_conf_ema_" << sub_pref_name(i)
             << " " << m_conf_ema[i] << endl;
    }

    cout << "meta_all_empty " << m_stats.all_empty << endl;
    cout << "meta_explore " << m_stats.meta_explore << endl;
    cout << "meta_exploit " << m_stats.meta_exploit << endl;
    cout << "meta_epsilon " << m_meta_epsilon << endl;
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
    cout << endl;
    cout << "--- Tsetlin Sub-Config ---" << endl;
    m_tsetlin->print_config();
    cout << "--- LinUCB Sub-Config ---" << endl;
    m_linucb->print_config();
    cout << "--- Stride Sub-Config ---" << endl;
    m_stride->print_config();
}
