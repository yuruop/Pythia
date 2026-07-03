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

    // ---- Accessors ----
    uint32_t num_actions() const { return m_num_actions; }

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
    uint64_t  address;         // prefetched address (0xdeadbeef = no-prefetch)
    int32_t*  features;        // snapshot of binary features at prediction time
    uint32_t  action_index;    // chosen action
    bool      is_filled;       // did the prefetched line arrive in cache?
    bool      has_reward;      // has the reward been assigned?
    int32_t   reward;          // reward value (0 = not yet assigned)
    int32_t   reward_type;     // 0=timely, 1=untimely, 2=incorrect, 3=none

    TMPrefetchTrackerEntry(uint64_t addr, const int32_t* feat, uint32_t act, uint32_t num_feat)
        : address(addr), action_index(act), is_filled(false),
          has_reward(false), reward(0), reward_type(-1)
    {
        features = new int32_t[num_feat];
        memcpy(features, feat, num_feat * sizeof(int32_t));
    }

    ~TMPrefetchTrackerEntry() {
        delete[] features;
    }
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
    uint32_t  m_pref_degree;
    bool      m_enable_dyn_degree;

    // ---------- Last-offset tracking table (lightweight stride detection) ----------
    // Simple direct-mapped table: page → last offset seen.
    // Replaces the hardcoded delta=0 stub with real stride computation.
    // Storage: 1024 entries × (8B tag + 4B offset + 1B valid) ≈ 13 KB
    //         (compressible to ~3 KB with 16-bit page tag truncation)
    static constexpr uint32_t LAST_OFFSET_TABLE_SIZE = 1024;
    struct LastOffsetEntry {
        uint64_t page_tag = 0;       // full page number for collision check
        int32_t  last_offset = -1;   // -1 = never written
        bool     valid = false;
    };
    LastOffsetEntry m_last_offset_table[LAST_OFFSET_TABLE_SIZE];

    // ---------- Temperature encoding bit allocation ----------
    // Hybrid scheme: temperature-encode ordinal features (offset, delta),
    // hash-encode categorical features (PC, page, bw_level).
    // Bit allocation computed from m_num_features at construction time.
    uint32_t m_temp_offset_bits;     // thermometer bits for block offset
    uint32_t m_temp_delta_bits;      // thermometer bits for delta magnitude
    uint32_t m_hash_feature_bits;    // remaining bits for hash encoding

    // ---------- RNG for exploration ----------
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
            std::vector<uint64_t> action_dist;
            std::vector<uint64_t> issue_dist;
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
    TsetlinPrefetcher(const TsetlinMachine::Config& tm_cfg,
                      const std::vector<int32_t>& actions,
                      uint32_t pt_size, uint32_t pref_degree,
                      float epsilon, uint8_t high_bw_thresh,
                      uint64_t seed, std::string type = "tsetlin");

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

private:
    // Generate binary features from program state
    void generate_features(uint64_t pc, uint64_t page, uint32_t offset,
                           int32_t delta, uint8_t bw_level, int32_t* features);

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
