/*
 * Tsetlin Machine Prefetcher for Pythia/ChampSim
 *
 * Implements a hardware-friendly multiclass Tsetlin Machine (Granmo, 2018)
 * for data prefetching. The TM uses only bitwise AND/OR/NOT operations and
 * saturating counters, making it inherently suitable for nanosecond-scale
 * hardware prefetch decisions.
 *
 * Key design decisions:
 * - Binary features are generated from program context (PC, page, offset,
 *   delta, bw_level) via XOR-based hashing → hardware-friendly, no multipliers
 * - Multiclass TM maps directly to prefetch action selection (each offset
 *   delta is a "class")
 * - Online learning uses Type I/II feedback driven by prefetch reward signals
 *   (timely, untimely, incorrect, no_prefetch)
 * - Prefetch Tracker (PT) mirrors Pythia's design for delayed reward assignment
 */

#ifndef TSETLIN_H
#define TSETLIN_H

#include <vector>
#include <deque>
#include <random>
#include <string>
#include <cstring>
#include "prefetcher.h"
#include "champsim.h"

using namespace std;

/*===========================================================================
 * Tsetlin Machine Core: Multiclass Tsetlin Machine adapted for prefetching
 *===========================================================================*/

// Each Tsetlin Automaton has 2 * num_states states.
// States 1..num_states        → action = EXCLUDE (0)
// States num_states+1..2N     → action = INCLUDE (1)
// The automaton starts near the boundary (randomly at N or N+1).

class TsetlinMachine {
public:
    struct Config {
        uint32_t num_clauses;        // total clauses across all actions
        uint32_t num_features;       // binary input feature count
        uint32_t num_actions;        // output action classes (prefetch offsets)
        uint32_t num_states;         // states per TA half (total states = 2*N)
        float    s;                  // precision parameter (controls pattern specificity)
        int32_t  threshold;          // voting threshold T
        uint64_t seed;               // RNG seed
    };

private:
    // ---------- TM Parameters ----------
    uint32_t m_num_clauses;
    uint32_t m_num_features;
    uint32_t m_num_actions;
    uint32_t m_num_states;           // total states = 2 * m_num_states
    float    m_s;
    int32_t  m_threshold;
    uint32_t m_clauses_per_action;

    // ---------- TA State Table ----------
    // ta_state[clause][feature][automaton_type]
    // automaton_type: 0 = include literal (x_k), 1 = include negated (¬x_k)
    // Flattened for cache efficiency: [clause * (num_features * 2)]
    // Each entry is a small uint8_t in [1, 2*num_states]
    uint8_t* m_ta_state;

    // ---------- Clause Metadata ----------
    // For each clause: which action class it belongs to, and its polarity
    // polarity +1 votes FOR the action, -1 votes AGAINST
    struct ClauseInfo {
        uint32_t action_class;
        int8_t   polarity;
    };
    ClauseInfo* m_clause_info;

    // ---------- Per-action clause indices ----------
    // For each action class, the starting clause index
    uint32_t* m_action_clause_start;

    // ---------- Pre-allocated working arrays (avoid hot-path allocation) ----------
    int32_t*  m_clause_output;       // [num_clauses]  output of each clause
    int32_t*  m_class_sum;           // [num_actions]  sum of votes per class
    int32_t*  m_feedback_to_clauses; // [num_clauses]  feedback type: +1 = Type I, -1 = Type II, 0 = none

    // ---------- RNG ----------
    std::mt19937                            m_rng;
    std::uniform_real_distribution<float>   m_dist;      // [0.0, 1.0)
    std::uniform_int_distribution<uint32_t> m_neg_dist;  // pre-allocated for hot path

public:
    TsetlinMachine(const Config& cfg);
    ~TsetlinMachine();

    // ---- Core Operations ----

    // Predict the best action for a binary feature vector.
    // features[0..num_features-1] must be {0,1}.
    // Returns: action index in [0, num_actions).
    uint32_t predict(const int32_t* features);

    // Online training update.
    // features: binary feature vector at prediction time
    // target_action: the action class to reinforce
    // is_positive: true → Type I feedback for target, Type II for random other
    //              false → Type II for target, Type I for random other
    void update(const int32_t* features, uint32_t target_action, bool is_positive);

    // Retrieve the vote sum for a specific action (proxy for confidence).
    int32_t get_class_sum(uint32_t action_class) const;

    // Retrieve the second-highest vote sum across all actions.
    // Used for margin-based confidence: margin = class_sum[best] - class_sum[second].
    // Returns 0 if there is only one action class.
    int32_t get_second_best_class_sum() const;

    // Predict and return the raw class_sum vote vector.
    // Used by feature-wise pooling: each sub-TM computes its votes, the
    // pooling layer aggregates them, then argmax over pooled votes.
    // Returns pointer to internal m_class_sum (valid until next predict/update call).
    const int32_t* predict_with_votes(const int32_t* features);

    // ---- Accessors ----
    uint32_t num_actions() const { return m_num_actions; }
    uint32_t num_features() const { return m_num_features; }

    // ---- Debug ----
    void dump_state() const;

private:
    // Translate automaton state to action (INCLUDE/EXCLUDE)
    inline int32_t ta_action(uint32_t state) const {
        return (state > m_num_states) ? 1 : 0;
    }

    // Calculate output of all clauses
    void calculate_clause_output(const int32_t* X, bool predict_mode);

    // Sum up votes per class
    void sum_up_class_votes();

    // Type I feedback: combats false negatives, produces frequent patterns
    void type_I_feedback(uint32_t clause_idx, const int32_t* X);

    // Type II feedback: combats false positives, increases discrimination
    void type_II_feedback(uint32_t clause_idx, const int32_t* X);

    // Resource allocation: probability of skipping feedback based on vote margin
    bool skip_feedback(float class_sum_val, int32_t polarity);
};


/*===========================================================================
 * Prefetch Tracker Entry
 *===========================================================================*/

class TMPrefetchTrackerEntry {
public:
    uint64_t  address;         // prefetched address (0xdeadbeef = no-prefetch sentinel)
    int32_t*  features;        // snapshot of binary features at prediction time
    uint32_t  action_index;    // chosen action
    bool      is_filled;       // did the prefetched line arrive in cache?
    bool      has_reward;      // has the reward been assigned?
    bool      is_sentinel;     // true → this entry represents no-prefetch or OOB
    int32_t   reward;          // reward value (0 = not yet assigned)
    int32_t   reward_type;     // 0=timely, 1=untimely, 2=incorrect, 3=none

    TMPrefetchTrackerEntry(uint64_t addr, const int32_t* feat, uint32_t act, uint32_t num_feat)
        : address(addr), action_index(act), is_filled(false),
          has_reward(false), is_sentinel(addr == 0xdeadbeef),
          reward(0), reward_type(-1)
    {
        features = new int32_t[num_feat];
        memcpy(features, feat, num_feat * sizeof(int32_t));
    }

    ~TMPrefetchTrackerEntry() {
        delete[] features;
    }
};


/*===========================================================================
 * Tsetlin Feature Group (P2.3: Feature-wise TM decomposition)
 *
 * Each TsetlinFeatureGroup holds one sub-TM responsible for a contiguous
 * slice of the flat binary features[] array.  Multiple sub-TMs run in
 * parallel; their vote vectors are pooled (max or weighted sum) to produce
 * the final action selection.
 *===========================================================================*/
struct TsetlinFeatureGroup {
    TsetlinMachine* tm;
    uint32_t        feat_start;    // offset into the flat features[] array
    uint32_t        feat_count;    // number of features used by this sub-TM
    const char*     name;          // debug label ("PC+Page", "Stride", "Context")
};

/*===========================================================================
 * Tsetlin Prefetcher: Wraps the TM for ChampSim integration
 *===========================================================================*/

class TsetlinPrefetcher : public Prefetcher {
public:
    // Reward types (mirrors Pythia's RewardType for consistency)
    enum RewardType {
        REWARD_TIMELY = 0,
        REWARD_UNTIMELY = 1,
        REWARD_INCORRECT = 2,
        REWARD_NONE = 3,
        NUM_REWARD_TYPES = 4
    };

private:
    // ---------- Core TM ----------
    TsetlinMachine*  m_tm;

    // ---------- Feature-wise TM decomposition (P2.3) ----------
    // When enabled, m_feature_tms replaces the monolithic m_tm.
    // Each sub-TM sees only one feature group; their vote vectors are
    // pooled (max or weighted sum) to produce the final action.
    bool                  m_featurewise;
    TsetlinFeatureGroup*  m_feature_tms;
    uint32_t              m_num_feature_tms;

    enum PoolingMode { POOL_WEIGHTED = 0, POOL_MAX = 1 };
    PoolingMode           m_pooling_mode;
    float*                m_tm_weights;        // [num_feature_tms] for weighted-sum pooling
    float                 m_tm_weight_lr;      // EMA decay for weight updates (0=disabled)

    // Cached pooled vote vector from the last feature-wise predict.
    // Filled by predict_featurewise(), consumed by get_dyn_pref_degree()
    // and confidence feedback (P1.4).  Stack-allocated to avoid heap
    // allocation on the hot path.
    static constexpr uint32_t MAX_POOLED_ACTIONS = 32;
    int32_t              m_pooled_class_sums[MAX_POOLED_ACTIONS];

    // ---------- Tile coding / Hash encoding mode (P2.4) ----------
    // 0 = hash encoding (original XOR+mix, no locality)
    // 1 = tile coding (overlapping tilings, preserves locality)
    enum EncodingMode { ENCODING_HASH = 0, ENCODING_TILE = 1 };
    EncodingMode         m_encoding;
    uint32_t             m_num_tilings;
    uint32_t             m_tiles_per_tiling;

    // ---------- Feature configuration ----------
    uint32_t         m_num_features;

    // ---------- Action space ----------
    std::vector<int32_t> m_actions;      // offset delta for each action index
    uint32_t             m_max_actions;

    // ---------- Prefetch Tracker (like Pythia's PT) ----------
    std::deque<TMPrefetchTrackerEntry*> m_pt;
    uint32_t  m_pt_size;

    // ---------- Bandwidth awareness ----------
    uint8_t   m_bw_level;
    uint8_t   m_high_bw_thresh;

    // ---------- Prefetch degree ----------
    uint32_t             m_pref_degree;
    bool                 m_enable_dyn_degree;
    std::vector<int32_t> m_dyn_deg_thresh;        // confidence thresholds (sorted ascending)
    std::vector<int32_t> m_dyn_deg_values;         // degree for each threshold bucket
    std::vector<int32_t> m_dyn_deg_thresh_hbw;     // high-BW variant thresholds
    std::vector<int32_t> m_dyn_deg_values_hbw;     // high-BW variant degrees

    // ---------- Last-offset tracking table (lightweight stride detection) ----------
    // Simple direct-mapped table: page → last offset seen.
    // Replaces the hardcoded delta=0 stub with real stride computation.
    // Storage: 1024 entries × (8B tag + 4B offset + 4B delta_sig + 4B delta_count + 1B valid) ≈ 21 KB
    //         (compressible to ~6 KB with 16-bit page tag truncation)
    static constexpr uint32_t LAST_OFFSET_TABLE_SIZE = 1024;

    // Delta signature constants (SPP-style encoding, P1.3)
    // Encodes the last 4 deltas into a 12-bit running hash via shift-XOR.
    // Each delta is encoded to 7-bit SPP format (sign-preserving) before mixing.
    static constexpr uint32_t DELTA_SIG_BIT      = 12;
    static constexpr uint32_t DELTA_SIG_SHIFT    = 3;
    static constexpr uint32_t DELTA_SIG_MASK     = (1u << DELTA_SIG_BIT) - 1;  // 0xFFF
    static constexpr uint32_t SPP_DELTA_ENC_BIT  = 7;   // SPP-style per-delta encoding width

    struct LastOffsetEntry {
        uint64_t page_tag = 0;       // full page number for collision check
        int32_t  last_offset = -1;   // -1 = never written
        uint32_t delta_sig = 0;      // running delta signature (shift-XOR hash, P1.3)
        uint32_t delta_count = 0;    // number of deltas accumulated (P1.3)
        uint32_t access_count = 0;   // saturating access counter, 0..255 (P1.4)
        int32_t  last_confidence = 0;// vote margin from last prediction (P1.4)
        int32_t  last_delta = 0;     // most recent delta value (P1.5)
        uint8_t  chaos_score = 0;    // delta irregularity EMA, 0=stable 255=random (P1.5)
        uint8_t  stride_streak = 0;  // P3.0: consecutive same-delta count for bootstrap
        bool     valid = false;
    };
    LastOffsetEntry m_last_offset_table[LAST_OFFSET_TABLE_SIZE];

    // ---------- Temperature encoding bit allocation ----------
    // Hybrid scheme with enhanced feature groups (P1.2).
    // Bit allocation computed from m_num_features at construction time.
    uint32_t m_temp_offset_bits;     // thermometer bits for block offset
    uint32_t m_temp_delta_bits;      // thermometer bits for delta magnitude (12 in P1.2)
    uint32_t m_interaction_bits;     // PC×Page interaction hash bits (4, NEW in P1.2)
    uint32_t m_temp_bw_bits;         // thermometer bits for BW level (2, NEW in P1.2)
    uint32_t m_delta_sig_bits;       // bitwise bits for delta signature (12, NEW in P1.3)
    uint32_t m_freq_bits;            // thermometer bits for access frequency (0=off, P1.4)
    uint32_t m_conf_bits;            // thermometer bits for confidence feedback (0=off, P1.4)
    int32_t  m_tm_threshold;         // TM voting threshold (for confidence max, P1.4)
    uint32_t m_hash_feature_bits;    // remaining bits for hash encoding

    // ---------- Epsilon-greedy annealing (P2.2) ----------
    float    m_epsilon_init;         // initial ε during warmup (e.g., 0.05)
    float    m_epsilon_min;          // floor ε after warmup (= configured epsilon)
    uint64_t m_warmup_invocations;   // decay over this many invocations
    uint64_t m_invocation_count;     // total invocations of invoke_prefetcher

    // ---------- RNG for exploration ----------
    std::mt19937                          m_rng;
    std::bernoulli_distribution           m_explore;
    std::uniform_int_distribution<int32_t> m_action_gen;

    // ---------- Confidence for meta-selector ----------
    // Normalized vote margin from the last prediction: margin / (margin_max + epsilon).
    // Updated on every invoke_prefetcher call, queried by MetaSelectorPrefetcher.
    float m_last_confidence_norm;

    // ---------- Statistics ----------
    struct {
        struct {
            uint64_t lookup;
            uint64_t hit;
            uint64_t evict;
            uint64_t evict_filled;    // evicted with is_filled=true → PT too small
            uint64_t evict_unfilled;  // evicted with is_filled=false → likely bad prefetch
            uint64_t insert;
        } pt;

        struct {
            uint64_t called;
            uint64_t explore;
            uint64_t exploit;
            uint64_t out_of_bounds;
            uint64_t predicted;
            uint64_t multi_deg_called;       // times multi-degree was invoked
            uint64_t multi_deg_issued;       // extra prefetches from multi-degree
            std::vector<uint64_t> action_dist;
            std::vector<uint64_t> issue_dist;
            std::vector<uint64_t> deg_histogram;       // which degree was selected
            std::vector<uint64_t> multi_deg_histogram; // extra prefetches per sub-degree
        } predict;

        struct {
            uint64_t called;
            uint64_t pt_not_found;
            uint64_t pt_found;
            uint64_t correct_timely;
            uint64_t correct_untimely;
            uint64_t incorrect;
            uint64_t no_pref;
            std::vector<uint64_t> reward_per_action[NUM_REWARD_TYPES];
        } reward;

        struct {
            uint64_t called;
            uint64_t learned_positive;
            uint64_t learned_negative;
            uint64_t learn_skipped_no_reward;
            uint64_t bootstrap_learned;   // P3.0: stride-teacher training events
        } learn;

        struct {
            uint64_t called;
            uint64_t set;
        } register_fill;

        // Feature-wise TM stats (P2.3)
        struct {
            uint64_t pooled_predicts;    // times feature-wise predict was used
            uint64_t group_predicts[8];  // per-group: times this group's vote matched final action
            uint64_t weight_updates;     // times sub-TM weights were updated
        } featurewise;

    } m_stats;

public:
    TsetlinPrefetcher(const TsetlinMachine::Config& tm_cfg,
                      const std::vector<int32_t>& actions,
                      uint32_t pt_size, uint32_t pref_degree,
                      float epsilon, uint8_t high_bw_thresh,
                      uint64_t seed, std::string type = "tsetlin",
                      bool enable_dyn_degree = false,
                      const std::vector<int32_t>& dyn_deg_thresh = {},
                      const std::vector<int32_t>& dyn_deg_values = {},
                      const std::vector<int32_t>& dyn_deg_thresh_hbw = {},
                      const std::vector<int32_t>& dyn_deg_values_hbw = {},
                      uint32_t temp_delta_bits = 8,
                      uint32_t interaction_bits = 0,
                      uint32_t temp_bw_bits = 0,
                      uint32_t delta_sig_bits = 12,
                      uint32_t freq_bits = 0,
                      uint32_t conf_bits = 0,
                      float epsilon_init = 0.005f,
                      uint64_t warmup_invocations = 0,
                      bool featurewise = false,
                      int32_t pooling_mode = 0,
                      float tm_weight_lr = 0.01f,
                      int32_t encoding_mode = 0,
                      uint32_t num_tilings = 4,
                      uint32_t tiles_per_tiling = 16);

    ~TsetlinPrefetcher();

    // ---- Prefetcher Interface ----
    void invoke_prefetcher(uint64_t pc, uint64_t address, uint8_t cache_hit,
                           uint8_t type, std::vector<uint64_t>& pref_addr) override;
    void register_fill(uint64_t address);
    void register_prefetch_hit(uint64_t address);
    void dump_stats() override;
    void print_config() override;

    // ---- Bandwidth/IPC updates (for system-aware operation) ----
    void update_bw(uint8_t bw_level);
    void update_ipc(uint8_t ipc);
    void update_acc(uint32_t acc_level);

    // ---- Accessors ----
    const char* get_reward_type_name(int32_t type) const;

    // Query the confidence of the last prediction (vote margin).
    // Returns the normalized vote margin (best - second_best) as a float.
    // Used by MetaSelectorPrefetcher to compare confidence across prefetchers.
    float get_last_confidence() const { return m_last_confidence_norm; }

    // Query PT hit count — total prefetches that were filled (useful).
    // Used by MetaSelectorPrefetcher for outcome-based accuracy tracking.
    uint64_t get_pt_hit_count() const { return m_stats.pt.hit; }

    // ---- PT control for meta-selector (P3) ----
    // Returns current number of entries in the prefetch tracker.
    uint32_t get_pt_size() const { return (uint32_t)m_pt.size(); }
    // Removes recently-added PT entries from the back until size == target_size.
    // Used by MetaSelectorPrefetcher to discard loser PT entries whose
    // predictions were never issued — prevents systematic negative feedback.
    void pop_pt_entries(uint32_t target_size);

private:
    // Generate binary features from program state (P1.4: +freq/conf)
    void generate_features(uint64_t pc, uint64_t page, uint32_t offset,
                           int32_t delta, uint8_t bw_level, uint32_t delta_sig,
                           uint32_t access_count, int32_t last_confidence,
                           int32_t* features);

    // P2.4: Tile-coding alternative to hash encoding for PC+Page features.
    // Produces num_tilings * tiles_per_tiling binary features, one-hot per tiling.
    // Similar (PC, page) inputs map to overlapping tiles → automatic generalization.
    void generate_tile_features(uint64_t pc, uint64_t page,
                                int32_t* features, uint32_t feat_start);

    // P2.3: Initialize feature-wise sub-TMs. Called from constructor when
    // m_featurewise==true. Allocates proportional clauses per group.
    void init_featurewise_tms(const TsetlinMachine::Config& base_cfg);

    // P2.3: Feature-wise predict — runs each sub-TM, pools their vote vectors,
    // returns argmax. Caches pooled votes in m_pooled_class_sums.
    uint32_t predict_featurewise(const int32_t* features);

    // P2.3: Feature-wise train — routes the same reward/update to all sub-TMs.
    void train_featurewise(const int32_t* features, uint32_t action, bool is_positive);

    // Compute reward for a PT entry
    int32_t compute_reward(TMPrefetchTrackerEntry* entry, int32_t reward_type);

    // Search PT for entries matching an address
    std::vector<TMPrefetchTrackerEntry*> search_pt(uint64_t address);

    // Train TM from a PT entry's reward
    void train_from_reward(TMPrefetchTrackerEntry* entry);

    // Generate multi-degree prefetch addresses
    void gen_multi_degree_pref(uint64_t page, uint32_t offset,
                                int32_t action_delta, uint32_t degree,
                                std::vector<uint64_t>& pref_addr);

    // Dynamic prefetch degree based on TM confidence
    uint32_t get_dyn_pref_degree(uint32_t action_index);

    // Check if currently in high bandwidth state
    bool is_high_bw() const;
};

#endif /* TSETLIN_H */
