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
    uint64_t  address;         // prefetched address (0xdeadbeef = no-prefetch)
    float*    features;        // snapshot of continuous features at prediction time
    uint32_t  action_index;    // chosen action
    bool      is_filled;       // did the prefetched line arrive in cache?
    bool      has_reward;      // has the reward been assigned?
    int32_t   reward;          // reward value (0 = not yet assigned)
    int32_t   reward_type;     // 0=timely, 1=untimely, 2=incorrect, 3=none

    CBPrefetchTrackerEntry(uint64_t addr, const float* feat, uint32_t act, uint32_t num_feat)
        : address(addr), action_index(act), is_filled(false),
          has_reward(false), reward(0), reward_type(-1)
    {
        features = new float[num_feat];
        memcpy(features, feat, num_feat * sizeof(float));
    }

    ~CBPrefetchTrackerEntry() {
        delete[] features;
    }
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
    static constexpr uint32_t DELTA_SIG_BIT    = 12;
    static constexpr uint32_t DELTA_SIG_SHIFT  = 3;
    static constexpr uint32_t DELTA_SIG_MASK   = (1u << DELTA_SIG_BIT) - 1;
    static constexpr uint32_t SIG_DELTA_BIT    = 7;

    struct LastOffsetEntry {
        uint64_t page_tag = 0;
        int32_t  last_offset = -1;
        uint32_t delta_sig = 0;      // running delta signature (P1.3)
        uint32_t delta_count = 0;    // number of deltas accumulated (P1.3)
        uint32_t access_count = 0;   // saturating access counter, 0..255 (P1.4)
        float    last_confidence = 0.0f; // |expected_reward| from last prediction (P1.4)
        bool     valid = false;
    };
    LastOffsetEntry m_last_offset_table[LAST_OFFSET_TABLE_SIZE];

    // ---------- Exploration ----------
    float    m_epsilon;

    // ---------- RNG ----------
    std::mt19937                          m_rng;
    std::bernoulli_distribution           m_explore;
    std::uniform_int_distribution<int32_t> m_action_gen;

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
        } learn;

        struct {
            uint64_t called;
            uint64_t set;
        } register_fill;

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
                               const std::vector<int32_t>& dyn_deg_values_hbw = {});

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

private:
    // Generate continuous features from program state (P1.4: +freq/conf)
    void generate_features(uint64_t pc, uint64_t page, uint32_t offset,
                           int32_t delta, uint8_t bw_level, uint32_t delta_sig,
                           uint32_t access_count, float last_confidence,
                           float* features);

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
