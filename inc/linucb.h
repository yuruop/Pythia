/*
 * Contextual Bandit (LinUCB) Prefetcher for Pythia/ChampSim
 *
 * Implements a hardware-friendly LinUCB (Linear Upper Confidence Bound)
 * contextual bandit algorithm for data prefetching. Each candidate prefetch
 * offset is an "arm", and the context vector encodes program state.
 *
 * Key design decisions:
 * - Sherman-Morrison incremental inverse covariance update (O(d²) per update)
 * - Continuous feature vector (6-8 dimensions) encodes PC, page, offset,
 *   delta, and bandwidth level
 * - Fixed-point compatible: all operations reduce to dot products and
 *   rank-1 outer-product updates
 * - Storage: ~1-3 KB for 8-dim features × 15 actions (very compact)
 *
 * Reference: Li et al., "A Contextual-Bandit Approach to Personalized
 * News Article Recommendation", WWW 2010.
 */

#ifndef LINUCB_H
#define LINUCB_H

#include <vector>
#include <deque>
#include <random>
#include <string>
#include <cstring>
#include <cmath>
#include "prefetcher.h"
#include "champsim.h"

using namespace std;

/*===========================================================================
 * LinUCB Core: Contextual Bandit with disjoint linear models per arm
 *
 * Each action i maintains:
 *   - A_i_inv: d×d inverse covariance matrix (initialized to (1/lambda)*I)
 *   - b_i:     d-dimensional accumulated reward-weighted feature vector
 *   - theta_i: d-dimensional weight vector = A_i_inv * b_i
 *
 * Predict:
 *   score_i = theta_i^T * x + alpha * sqrt(x^T * A_i_inv * x)
 *   return argmax_i(score_i)
 *
 * Update (Sherman-Morrison):
 *   A_inv = A_inv - (A_inv * x * x^T * A_inv) / (1 + x^T * A_inv * x)
 *   b = b + reward * x
 *   theta = A_inv * b
 *===========================================================================*/

class LinUCB {
public:
    struct Config {
        uint32_t num_actions;        // number of arms (prefetch offsets)
        uint32_t num_features;       // dimensionality of context vector
        float    alpha;              // exploration parameter (UCB bonus scale)
        float    lambda_;            // L2 regularization (ridge regression)
        uint64_t seed;               // RNG seed
    };

private:
    uint32_t m_num_actions;
    uint32_t m_num_features;
    float    m_alpha;
    float    m_lambda;

    // Per-action parameters (flattened for cache efficiency)
    // A_inv[i] = i-th action's d×d inverse covariance matrix (row-major)
    float*  m_A_inv;       // [num_actions × num_features × num_features]
    float*  m_b;           // [num_actions × num_features]  reward-weighted sum
    float*  m_theta;       // [num_actions × num_features]  weight vector

    // Working buffers (pre-allocated to avoid hot-path allocation)
    float*  m_Ax;          // [num_features]  A_inv * x

public:
    LinUCB(const Config& cfg);
    ~LinUCB();

    // ---- Core Operations ----

    // Predict the best action for a continuous feature vector.
    // features[0..num_features-1] are real-valued (typically normalized to [-1,1] or [0,1]).
    // Returns: action index in [0, num_actions).
    uint32_t predict(const float* features);

    // Predict with full score information.
    // Fills out_scores[0..num_actions-1] with UCB scores and optionally returns
    // best_score / avg_score for suppression gating.
    // Returns: best action index.
    uint32_t predict_with_scores(const float* features, float* out_scores,
                                  float* out_best_score, float* out_avg_score);

    // Online training update using Sherman-Morrison.
    // features: context vector at prediction time
    // action: the chosen action index
    // reward: scalar reward signal (positive = reinforce, negative = penalize)
    void update(const float* features, uint32_t action, float reward);

    // ---- Accessors ----
    uint32_t num_actions()  const { return m_num_actions; }
    uint32_t num_features() const { return m_num_features; }
    float    get_theta(uint32_t action, uint32_t feat) const;
    float    get_ucb_bonus(const float* features, uint32_t action) const;
    float    get_expected_reward(const float* features, uint32_t action) const;

    // ---- Debug ----
    void dump_state() const;

private:
    // Vector dot product: Σ a[i] * b[i]
    inline float dot(const float* a, const float* b) const;

    // Matrix-vector multiply: out = mat * vec
    void mat_vec_mul(const float* mat, const float* vec, float* out) const;

    // Rank-1 outer product update: mat -= scale * (a ⊗ b)
    // i.e., mat[i][j] -= scale * a[i] * b[j]
    void outer_product_sub(float* mat, const float* a, const float* b, float scale);
};


/*===========================================================================
 * CB Prefetch Tracker Entry
 *===========================================================================*/

class CBPrefetchTrackerEntry {
public:
    uint64_t  address;         // prefetched address (0xdeadbeef = no-prefetch sentinel)
    float*    features;        // snapshot of continuous features at prediction time
    uint32_t  action_index;    // chosen action
    bool      is_filled;       // did the prefetched line arrive in cache?
    bool      has_reward;      // has the reward been assigned?
    bool      is_sentinel;     // true → this entry represents no-prefetch or OOB
    int32_t   reward;          // reward value (0 = not yet assigned)
    int32_t   reward_type;     // 0=timely, 1=untimely, 2=incorrect, 3=none

    CBPrefetchTrackerEntry(uint64_t addr, const float* feat, uint32_t act, uint32_t num_feat)
        : address(addr), action_index(act), is_filled(false),
          has_reward(false), is_sentinel(addr == 0xdeadbeef),
          reward(0), reward_type(-1)
    {
        features = new float[num_feat];
        memcpy(features, feat, num_feat * sizeof(float));
    }

    ~CBPrefetchTrackerEntry() {
        delete[] features;
    }
};


/*===========================================================================
 * LinUCB Feature Model (P2.3: Feature-wise LinUCB decomposition)
 *
 * Each LinUCBFeatureModel holds one sub-LinUCB responsible for a contiguous
 * slice of the flat float features[] array.  Multiple sub-models run in
 * parallel; their UCB scores are pooled (max or weighted sum) to produce
 * the final action selection.
 *===========================================================================*/
struct LinUCBFeatureModel {
    LinUCB*  model;
    uint32_t feat_start;        // offset into flat features[] array
    uint32_t feat_count;        // number of features for this sub-model
    float    weight;            // for weighted-sum pooling
    float    accuracy_ema;      // EMA of correctness rate
};

/*===========================================================================
 * Contextual Bandit Prefetcher: Wraps LinUCB for ChampSim integration
 *===========================================================================*/

class ContextualBanditPrefetcher : public Prefetcher {
public:
    // Reward types (same as Pythia/Tsetlin for consistency)
    enum RewardType {
        REWARD_TIMELY = 0,
        REWARD_UNTIMELY = 1,
        REWARD_INCORRECT = 2,
        REWARD_NONE = 3,
        NUM_REWARD_TYPES = 4
    };

private:
    // ---------- Core LinUCB ----------
    LinUCB*          m_linucb;

    // ---------- Feature-wise LinUCB decomposition (P2.3) ----------
    // When enabled, m_feature_models replaces the monolithic m_linucb.
    // Each sub-model sees only one feature group; their UCB scores are
    // pooled (max or weighted sum) to produce the final action.
    bool                  m_featurewise;
    LinUCBFeatureModel*   m_feature_models;
    uint32_t              m_num_feature_models;
    enum LcbPoolingMode { LCB_POOL_WEIGHTED = 0, LCB_POOL_MAX = 1 };
    LcbPoolingMode        m_lcb_pooling;
    float                 m_lcb_weight_lr;
    float                 m_lcb_weight_reg;    // prior strength for weight softmax

    // Cached scores from the last predict for downstream use
    // (suppression gating, dynamic degree, confidence feedback).
    float    m_cached_best_score;
    float    m_cached_avg_score;
    float    m_cached_scores[32];  // max 32 actions

    // ---------- Feature configuration ----------
    uint32_t         m_num_features;

    // ---------- Action space ----------
    std::vector<int32_t> m_actions;      // offset delta for each action index
    uint32_t             m_max_actions;

    // ---------- Prefetch Tracker ----------
    std::deque<CBPrefetchTrackerEntry*> m_pt;
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

    // ---------- Last-offset tracking table ----------
    // Same lightweight stride detection as Tsetlin.
    // P1.3: extended with delta signature tracking.
    static constexpr uint32_t LAST_OFFSET_TABLE_SIZE = 1024;

    // Delta signature constants (SPP-style encoding, P1.3)
    static constexpr uint32_t DELTA_SIG_BIT      = 12;
    static constexpr uint32_t DELTA_SIG_SHIFT    = 3;
    static constexpr uint32_t DELTA_SIG_MASK     = (1u << DELTA_SIG_BIT) - 1;
    static constexpr uint32_t SPP_DELTA_ENC_BIT  = 7;   // SPP-style per-delta encoding width

    struct LastOffsetEntry {
        uint64_t page_tag = 0;
        int32_t  last_offset = -1;
        uint32_t delta_sig = 0;      // running delta signature (P1.3)
        uint32_t delta_count = 0;    // number of deltas accumulated (P1.3)
        uint32_t access_count = 0;   // saturating access counter, 0..255 (P1.4)
        float    last_confidence = 0.0f; // |expected_reward| from last prediction (P1.4)
        int32_t  last_delta = 0;     // most recent delta value (P1.5)
        uint8_t  stride_streak = 0;  // consecutive same-delta count (P1.5)
        float    delta_var_ema = 0.0f; // EMA of |delta - prev_delta| / 64 (P2.7)
        bool     valid = false;
    };
    LastOffsetEntry m_last_offset_table[LAST_OFFSET_TABLE_SIZE];

    // ---------- Exploration ----------
    float    m_epsilon;

    // ---------- Confidence for meta-selector ----------
    // Cached UCB best-score from the last prediction.
    // Updated on every invoke_prefetcher call, queried by MetaSelectorPrefetcher.
    float m_last_confidence;

    // ---------- RNG ----------
    // Must be declared BEFORE m_reward_* members because the constructor
    // initializer list initializes RNG objects first.
    std::mt19937                          m_rng;
    std::bernoulli_distribution           m_explore;
    std::uniform_int_distribution<int32_t> m_action_gen;
    std::uniform_real_distribution<float> m_dist;  // P1.5: for adaptive agg

    // ---------- Adaptive aggressiveness (P1.5, fixed P1.6) ----------
    // Tracks a sliding window of recent scaled rewards to detect when the
    // bandit is consistently receiving negative feedback — a sign that the
    // current access pattern is not prefetch-friendly (e.g., random pointer
    // chasing).  When the recent average reward drops below a threshold,
    // the prefetcher probabilistically biases toward "no-prefetch".
    //
    // P1.6 FIX: The original P1.5 implementation created a cold-start
    // deadlock — early negative rewards triggered deterministic suppression,
    // which prevented any future prefetches from being issued, which meant
    // no positive rewards could ever arrive to lift the suppression.
    // Fixes applied:
    //   (a) WARMUP_SAMPLES: suppression is fully disabled until enough
    //       samples accumulate (2× REWARD_WINDOW).
    //   (b) Suppression is SOFT (probabilistic), not HARD (deterministic).
    //   (c) Suppression is skipped during ε-greedy exploration so random
    //       probes can still break out of a negative cycle.
    //   (d) Threshold uses the RATIO of positive rewards in the window
    //       (not raw average), which is invariant to reward scale.
    //   (e) Even under max suppression, a 5% escape probability is
    //       retained so the bandit can recover autonomously.
    static constexpr uint32_t REWARD_WINDOW   = 256;
    static constexpr uint32_t WARMUP_SAMPLES  = 512;  // 2× REWARD_WINDOW (P1.6)
    static constexpr uint32_t BOOTSTRAP_SAMPLES = 1536;  // P3.1e: 3× WARMUP, extended stride-teacher period
    float  m_reward_ring[REWARD_WINDOW];    // sliding window of recent rewards
    uint32_t m_reward_head;                 // ring buffer write position
    float  m_reward_sum;                    // running sum for O(1) average
    float  m_reward_count;                  // number of samples accumulated
    float  m_positive_sum;                  // running sum of positive-reward fraction (P1.6)
    uint32_t m_no_pref_action_idx;          // cached index of action=0

    // ---------- UCB score ratio gating (P2.5) ----------
    // Suppress prefetch when the best UCB score is not significantly better
    // than the average — all actions have similar scores → no clear winner,
    // issuing a prefetch would be random speculation.
    bool    m_suppress_gating;
    float   m_suppress_ratio;               // threshold: best_score / avg_score must exceed this

    // ---------- Path/history features (P2.6) ----------
    // Maintain small queues of recent PCs and deltas to capture temporal context.
    // Two extra features are appended after the existing features:
    //   [num_features-2]: hash of recent PCs
    //   [num_features-1]: hash of recent deltas
    static constexpr uint32_t HISTORY_DEPTH = 4;
    bool     m_history_features;
    uint64_t m_recent_pcs[HISTORY_DEPTH];     // circular buffer
    int32_t  m_recent_deltas[HISTORY_DEPTH];  // circular buffer
    uint32_t m_history_head;                  // write position
    uint32_t m_history_count;                 // entries filled so far

    // ---------- Statistics ----------
    struct {
        struct {
            uint64_t lookup;
            uint64_t hit;
            uint64_t evict;
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
            uint64_t gating_checked;         // P2.5: times score ratio was checked
            uint64_t gating_suppressed;      // P2.5: times gating forced no-prefetch
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
            uint64_t suppressed;          // times suppression forced no-prefetch (P1.6)
            uint64_t suppressed_prob;     // times probabilistic suppression hit (P1.6)
            uint64_t suppressed_escape;   // times escape probability let prefetch through (P1.6)
        } suppress;

        struct {
            uint64_t called;
            uint64_t set;
        } register_fill;

        // Feature-wise stats (P2.3)
        struct {
            uint64_t pooled_predicts;
            uint64_t model_agrees[8];   // per-model agreement with final action
            uint64_t weight_updates;
        } featurewise;

    } m_stats;

public:
    ContextualBanditPrefetcher(const LinUCB::Config& cb_cfg,
                               const std::vector<int32_t>& actions,
                               uint32_t pt_size,
                               uint32_t pref_degree,
                               float epsilon,
                               uint8_t high_bw_thresh,
                               uint64_t seed,
                               std::string type = "linucb",
                               bool enable_dyn_degree = false,
                               const std::vector<int32_t>& dyn_deg_thresh = {},
                               const std::vector<int32_t>& dyn_deg_values = {},
                               const std::vector<int32_t>& dyn_deg_thresh_hbw = {},
                               const std::vector<int32_t>& dyn_deg_values_hbw = {},
                               bool featurewise = false,
                               int32_t lcb_pooling_mode = 0,
                               float lcb_weight_lr = 0.01f,
                               bool suppress_gating = false,
                               float suppress_ratio = 1.5f,
                               bool history_features = false);

    ~ContextualBanditPrefetcher();

    // ---- Prefetcher Interface ----
    void invoke_prefetcher(uint64_t pc, uint64_t address, uint8_t cache_hit,
                           uint8_t type, std::vector<uint64_t>& pref_addr) override;
    void register_fill(uint64_t address);
    void register_prefetch_hit(uint64_t address);
    void dump_stats() override;
    void print_config() override;

    // ---- Bandwidth/IPC updates ----
    void update_bw(uint8_t bw_level);
    void update_ipc(uint8_t ipc);
    void update_acc(uint32_t acc_level);

    // ---- Accessors ----
    const char* get_reward_type_name(int32_t type) const;

    // Query the confidence of the last prediction.
    // Returns the UCB score of the best action from the last prediction (cached).
    // Used by MetaSelectorPrefetcher to compare confidence across prefetchers.
    float get_last_confidence() const { return m_last_confidence; }

    // Query PT hit count — total prefetches that were filled (useful).
    // Used by MetaSelectorPrefetcher for outcome-based accuracy tracking.
    uint64_t get_pt_hit_count() const { return m_stats.pt.hit; }

    // ---- PT control for meta-selector (P3) ----
    // Returns current number of entries in the prefetch tracker.
    uint32_t get_pt_size() const { return (uint32_t)m_pt.size(); }
    // Removes recently-added PT entries from the back until size == target_size.
    // Used by MetaSelectorPrefetcher to discard loser PT entries.
    void pop_pt_entries(uint32_t target_size);

private:
    // Generate continuous features from program state (P1.5: +stride_streak)
    void generate_features(uint64_t pc, uint64_t page, uint32_t offset,
                           int32_t delta, uint8_t bw_level, uint32_t delta_sig,
                           uint32_t access_count, float last_confidence,
                           uint8_t stride_streak, float* features);

    // P2.6: Generate history (path) features from recent PC/delta queues.
    // Appends 2 features at indices [num_features-2, num_features-1].
    void generate_history_features(float* features);

    // P2.3: Initialize feature-wise sub-models. Called from constructor when
    // m_featurewise==true. Defines natural feature groups (PC, Page, Offset,
    // Delta, Interaction, Context) and creates per-group LinUCB instances.
    void init_featurewise_models(const LinUCB::Config& base_cfg);

    // P2.3: Feature-wise predict — runs each sub-model, pools their UCB scores,
    // returns argmax. Caches best/avg scores in m_cached_* members.
    uint32_t predict_featurewise(const float* features);

    // P2.3: Feature-wise train — routes the same scaled reward to all sub-models.
    void train_featurewise(const float* features, uint32_t action, float scaled_reward);

    // Hash a 64-bit value to a normalized float in [0, 1]
    inline float hash_to_float(uint64_t value, uint32_t seed) const;

    // Compute reward for a PT entry
    int32_t compute_reward(CBPrefetchTrackerEntry* entry, int32_t reward_type);

    // Search PT for entries matching an address
    std::vector<CBPrefetchTrackerEntry*> search_pt(uint64_t address);

    // Train LinUCB from a PT entry's reward
    void train_from_reward(CBPrefetchTrackerEntry* entry);

    // Check if currently in high bandwidth state
    bool is_high_bw() const;

    // Dynamic prefetch degree based on LinUCB expected reward confidence
    uint32_t get_dyn_pref_degree(const float* features, uint32_t action_index);

    // Generate multi-degree speculative prefetch addresses
    void gen_multi_degree_pref(uint64_t page, uint32_t offset,
                                int32_t action_delta, uint32_t degree,
                                std::vector<uint64_t>& pref_addr);
};

#endif /* LINUCB_H */
