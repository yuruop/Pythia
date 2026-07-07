/*
 * Meta-Selector Prefetcher for Pythia/ChampSim
 *
 * Layer 2 of the multi-layer adaptive prefetching system.
 *
 * Runs three base prefetchers simultaneously in an online-learning ensemble:
 *   1. Tsetlin Machine  — binary-feature rule learner (good at pattern recognition)
 *   2. LinUCB Bandit    — continuous-feature linear bandit (good at nuanced patterns)
 *   3. Stride           — traditional stride detector (fallback only)
 *
 * All three prefetchers update their internal state on every demand access.
 * The meta-selector uses UCB (Upper Confidence Bound) on actual prefetch accuracy
 * (PT hit rate) to select between Tsetlin and LinUCB.  Stride is used only as a
 * fallback when both ML prefetchers produce empty predictions.
 *
 * PT management: After all three invoke_prefetcher() (which creates PT entries),
 * the losers' newly-created PT entries are immediately discarded.  Only the
 * winner's PT entries survive — because only the winner's predictions were
 * actually issued.  This prevents systematic negative feedback: an unissued
 * prediction can never be filled, so it should never exist in the PT.
 *
 * Accuracy tracking (P4 — outcome-based selection):
 *   Periodically samples each sub-prefetcher's PT hit count and computes
 *   accuracy = delta_hits / delta_issued over the sampling window.
 *   An EMA smooths the accuracy estimate, and UCB adds exploration bonus.
 *
 * Context-aware selection (P5):
 *   A PC-indexed table tracks per-context accuracy for 256 PC buckets.
 *   Context-specific accuracy is blended with global accuracy for more
 *   precise prefetcher selection per program region.
 *
 * Confidence metrics (retained as secondary signal):
 *   - Tsetlin: vote margin (best_class_sum - second_best_class_sum) normalized
 *   - LinUCB:  |expected_reward| of the best action, normalized
 *   - Stride:  streak-based (0→1 ramp over 8 consecutive matches)
 *
 * All register_fill / register_prefetch_hit / broadcast events are forwarded
 * to all three sub-prefetchers so they continue learning regardless of which
 * one was selected.
 */

#ifndef META_SELECTOR_H
#define META_SELECTOR_H

#include <vector>
#include <random>
#include <string>
#include <cmath>
#include "prefetcher.h"
#include "tsetlin.h"
#include "linucb.h"
#include "stride.h"

using namespace std;

class MetaSelectorPrefetcher : public Prefetcher {
public:
    // Sub-prefetcher indices
    enum SubPref {
        SP_TSETLIN = 0,
        SP_LINUCB  = 1,
        SP_STRIDE  = 2,
        SP_COUNT   = 3
    };

private:
    // ---------- Three sub-prefetchers ----------
    TsetlinPrefetcher*           m_tsetlin;
    ContextualBanditPrefetcher*  m_linucb;
    StridePrefetcher*            m_stride;

    // Prefetch address buffers (one per sub-prefetcher)
    std::vector<uint64_t> m_buffers[SP_COUNT];

    // ---------- Confidence normalization (secondary signal) ----------
    float m_conf_ema[SP_COUNT];   // EMA of raw confidence per prefetcher
    float m_conf_alpha;           // EMA decay factor (default 0.1 — faster adaptation)

    // ---------- Outcome-based accuracy tracking (P4: primary selection signal) ----------
    // Periodically sample PT hit counts to compute actual prefetch accuracy.
    // Accuracy = delta_hits / delta_issued over the sampling window.
    uint64_t m_last_pt_hit[SP_COUNT];       // PT hit count snapshot from last sample
    uint64_t m_issued_since_sample[SP_COUNT]; // prefetches issued since last sample
    float    m_accuracy_ema[SP_COUNT];       // EMA of per-prefetcher accuracy
    float    m_accuracy_alpha;               // EMA decay for accuracy (default 0.1)
    uint32_t m_sample_interval;              // invocations between accuracy updates
    uint32_t m_sample_counter;               // countdown for next accuracy sample
    int32_t  m_last_winner;                  // last selected sub-prefetcher (for fill credit)

    // Accuracy tracking needs a sampled flag because EMA can legitimately be 0.0
    // after sampling (if no PT hits occurred).  Using m_accuracy_ema == 0.0f to
    // detect "never sampled" would incorrectly re-trigger cold-start logic.
    bool     m_has_sampled;                    // true after first update_accuracy() call

    // ---------- UCB selection parameters ----------
    float    m_ucb_c;                        // UCB exploration constant (default 2.0)

    // ---------- Context-aware selection (P5) ----------
    static constexpr uint32_t CTX_TABLE_BITS = 8;
    static constexpr uint32_t CTX_TABLE_SIZE = 1 << CTX_TABLE_BITS;
    struct ContextEntry {
        float    acc_ema[SP_COUNT];   // per-prefetcher accuracy EMA for this PC context
        uint64_t sample_count;        // total samples in this context
    };
    ContextEntry m_ctx_table[CTX_TABLE_SIZE];
    float  m_ctx_blend;                  // context vs global blend factor (default 0.5)
    uint64_t m_last_pc;                  // PC of last invocation (for context update)

    // ---------- Selection statistics ----------
    uint64_t m_selected_count[SP_COUNT];  // times each prefetcher was selected
    uint64_t m_total_invocations;

    // ---------- RNG for tie-breaking / meta-exploration ----------
    std::mt19937 m_rng;

    // Meta-level exploration: with probability m_meta_epsilon, a random
    // ML prefetcher is selected regardless of accuracy.  Reduced from the
    // confidence-only design since UCB provides its own exploration bonus.
    float m_meta_epsilon;  // default 0.02 = 2% random selection

    // ---------- BW tracking (forwarded to sub-prefetchers) ----------
    uint8_t m_bw_level;

    // ---------- Statistics ----------
    struct {
        uint64_t all_empty;          // all three produced empty predictions
        uint64_t meta_explore;       // times meta-level exploration was used
        uint64_t meta_exploit;       // times UCB-based selection was used
        uint64_t stride_fallback;    // times stride was selected as fallback (both ML empty)
        uint64_t single_ml;          // times only one ML prefetcher had predictions
    } m_stats;

public:
    MetaSelectorPrefetcher(
        const TsetlinMachine::Config& tm_cfg,
        const LinUCB::Config& cb_cfg,
        const std::vector<int32_t>& actions,
        uint32_t pt_size,
        uint32_t pref_degree,
        float epsilon,
        uint8_t high_bw_thresh,
        uint64_t seed,
        std::string type,
        // ---- Tsetlin-specific ----
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
        // ---- LinUCB-specific ----
        bool linucb_featurewise,
        int32_t linucb_lcb_pooling,
        float linucb_lcb_weight_lr,
        bool linucb_suppress_gating,
        float linucb_suppress_ratio,
        bool linucb_history_features,
        // ---- Meta-selector-specific ----
        float meta_conf_alpha = 0.1f,
        float meta_epsilon = 0.02f,
        float meta_accuracy_alpha = 0.1f,
        float meta_ucb_c = 2.0f,
        uint32_t meta_sample_interval = 1000,
        float meta_ctx_blend = 0.5f);

    ~MetaSelectorPrefetcher();

    // ---- Prefetcher Interface ----
    void invoke_prefetcher(uint64_t pc, uint64_t address, uint8_t cache_hit,
                           uint8_t type, std::vector<uint64_t>& pref_addr) override;
    void register_fill(uint64_t address);
    void register_prefetch_hit(uint64_t address);
    void dump_stats() override;
    void print_config() override;

    // ---- Bandwidth/IPC/ACC updates (forwarded to all sub-prefetchers) ----
    void update_bw(uint8_t bw_level);
    void update_ipc(uint8_t ipc);
    void update_acc(uint32_t acc_level);

private:
    // Select the best sub-prefetcher based on UCB accuracy + context blending.
    // Stride is only used as fallback (improvement #2).
    int32_t select_best_prefetcher(uint64_t pc);

    // Periodically sample PT hit counts and update accuracy EMAs.
    void update_accuracy();

    // Query a sub-prefetcher's PT hit count (0 for Stride which has no PT).
    uint64_t get_sub_pt_hits(int32_t idx) const;

    // Get the name of a sub-prefetcher by index.
    const char* sub_pref_name(int32_t idx) const;
};

#endif /* META_SELECTOR_H */
