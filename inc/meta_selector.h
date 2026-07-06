/*
 * Meta-Selector Prefetcher for Pythia/ChampSim
 *
 * Layer 2 of the multi-layer adaptive prefetching system.
 *
 * Runs three base prefetchers simultaneously in an online-learning ensemble:
 *   1. Tsetlin Machine  — binary-feature rule learner (good at pattern recognition)
 *   2. LinUCB Bandit    — continuous-feature linear bandit (good at nuanced patterns)
 *   3. Stride           — traditional stride detector (good at simple regular patterns)
 *
 * All three prefetchers update their internal state on every demand access.
 * The meta-selector computes a confidence score for each and selects the most
 * confident prefetcher's predictions for actual issue.
 *
 * Confidence metrics:
 *   - Tsetlin: vote margin (best_class_sum - second_best_class_sum) normalized
 *   - LinUCB:  |expected_reward| of the best action, normalized
 *   - Stride:  binary (1.0 if stride matched, 0.0 if not)
 *
 * Selection: Each confidence is EMA-normalized (self-calibrating), then the max
 * is chosen.  Tie-breaking prefers Stride > Tsetlin > LinUCB.
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

    // ---------- Confidence normalization ----------
    // Each sub-prefetcher reports confidence on a different scale.
    // We track an EMA of each to self-normalize:
    //   norm_conf[i] = raw_conf[i] / (ema_conf[i] + epsilon)
    float m_conf_ema[SP_COUNT];   // EMA of raw confidence per prefetcher
    float m_conf_alpha;           // EMA decay factor (0.01 = slow adaptation)

    // ---------- Selection statistics ----------
    uint64_t m_selected_count[SP_COUNT];  // times each prefetcher was selected
    uint64_t m_total_invocations;

    // ---------- RNG for tie-breaking / meta-exploration ----------
    std::mt19937 m_rng;

    // Meta-level exploration: with probability m_meta_epsilon, a random
    // prefetcher is selected regardless of confidence.  This prevents
    // training starvation: non-winners' PT entries would otherwise never
    // get filled (their predictions are never issued), leading to systematic
    // negative rewards and model decay for the losing prefetchers.
    float m_meta_epsilon;  // default 0.05 = 5% random selection

    // ---------- BW tracking (forwarded to sub-prefetchers) ----------
    uint8_t m_bw_level;

    // ---------- Statistics ----------
    struct {
        uint64_t all_no_prefetch;    // all three predicted no-prefetch
        uint64_t all_empty;          // all three produced empty predictions
        uint64_t meta_explore;       // times meta-level exploration was used
        uint64_t meta_exploit;       // times confidence-based selection was used
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
        float meta_conf_alpha = 0.01f,
        float meta_epsilon = 0.05f);

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
    // Select the best sub-prefetcher based on normalized confidence.
    int32_t select_best_prefetcher();

    // Get the name of a sub-prefetcher by index.
    const char* sub_pref_name(int32_t idx) const;
};

#endif /* META_SELECTOR_H */
