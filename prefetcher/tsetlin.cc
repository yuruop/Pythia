/*
 * Tsetlin Machine Prefetcher Implementation
 *
 * Implements a hardware-friendly multiclass Tsetlin Machine for data prefetching.
 * Core algorithm based on: Granmo, "The Tsetlin Machine", arXiv:1804.01508 (2018).
 *
 * Hardware-friendliness analysis:
 * - predict():  Only AND/OR/NOT + integer comparisons → nanosecond-scale
 * - update():   Only saturating counter ±1 + random bits → incremental, low-cost
 * - Storage:    ~6-16 KB for state table (configurable) → within cache budget
 * - All operations are bitwise or simple integer → no multipliers/FPU needed
 */

#include <iostream>
#include <iomanip>
#include <cassert>
#include "tsetlin.h"

using namespace std;

// Maximum supported feature dimensionality for stack-allocated buffers.
// Must be >= m_num_features.  Used in invoke_prefetcher() — the hot path —
// to avoid heap allocation (new/delete) on every demand request.
// P1.3: increased 64→128 to accommodate delta signature bits and future expansion.
static constexpr uint32_t MAX_FEATURES = 128;

/* =========================================================================
 * TsetlinMachine Implementation
 * ========================================================================= */

TsetlinMachine::TsetlinMachine(const Config& cfg)
    : m_num_clauses(cfg.num_clauses)
    , m_num_features(cfg.num_features)
    , m_num_actions(cfg.num_actions)
    , m_num_states(cfg.num_states)
    , m_s(cfg.s)
    , m_threshold(cfg.threshold)
    , m_rng(cfg.seed)
    , m_dist(0.0f, 1.0f)
    , m_neg_dist(0, cfg.num_actions > 1 ? cfg.num_actions - 1 : 0)
{
    // Clauses per action (evenly distributed)
    m_clauses_per_action = m_num_clauses / m_num_actions;
    // Runtime check (not assert) — in Release/NDEBUG builds, assert is removed
    // and the TM would silently degrade with zero clauses, all arrays size-0.
    if (m_clauses_per_action < 2) {
        cerr << "FATAL: Need at least 2 clauses per action, got "
             << m_clauses_per_action << " (num_clauses=" << m_num_clauses
             << ", num_actions=" << m_num_actions << ")" << endl;
        abort();
    }

    // Trim excess clauses: only keep clauses that are evenly distributable
    // across actions. Excess clauses have uninitialized metadata and cause
    // out-of-bounds writes in sum_up_class_votes() when garbage action_class
    // indices exceed m_num_actions.
    m_num_clauses = m_clauses_per_action * m_num_actions;

    // Allocate and initialize TA state table
    // ta_state[clause][feature][2]: flattened to [clause * (features * 2)]
    size_t state_size = m_num_clauses * m_num_features * 2;
    m_ta_state = new uint8_t[state_size];

    // Randomly initialize each automaton to either N or N+1 (the boundary)
    std::uniform_int_distribution<int32_t> init_dist(0, 1);
    for (size_t i = 0; i < state_size; i++) {
        m_ta_state[i] = m_num_states + init_dist(m_rng);  // N or N+1
    }

    // Allocate clause metadata
    m_clause_info = new ClauseInfo[m_num_clauses];

    // Assign clauses to actions with alternating polarity
    for (uint32_t action = 0; action < m_num_actions; action++) {
        uint32_t base = action * m_clauses_per_action;
        for (uint32_t j = 0; j < m_clauses_per_action; j++) {
            uint32_t clause_idx = base + j;
            m_clause_info[clause_idx].action_class = action;
            // Half positive, half negative polarity per action
            m_clause_info[clause_idx].polarity = (j % 2 == 0) ? 1 : -1;
        }
    }

    // Per-action clause start indices
    m_action_clause_start = new uint32_t[m_num_actions];
    for (uint32_t action = 0; action < m_num_actions; action++) {
        m_action_clause_start[action] = action * m_clauses_per_action;
    }

    // Allocate working arrays
    m_clause_output       = new int32_t[m_num_clauses];
    m_class_sum           = new int32_t[m_num_actions];
    m_feedback_to_clauses = new int32_t[m_num_clauses];
}

TsetlinMachine::~TsetlinMachine() {
    delete[] m_ta_state;
    delete[] m_clause_info;
    delete[] m_action_clause_start;
    delete[] m_clause_output;
    delete[] m_class_sum;
    delete[] m_feedback_to_clauses;
}

/* -------------------------------------------------------------------------
 * clause_output calculation
 * clause_output[j] = 1 if all INCLUDED literals match X, else 0
 * If predict_mode: clauses with all-excluded literals → output 0 (inactive)
 * ------------------------------------------------------------------------- */
void TsetlinMachine::calculate_clause_output(const int32_t* X, bool predict_mode) {
    for (uint32_t j = 0; j < m_num_clauses; j++) {
        m_clause_output[j] = 1;
        bool all_exclude = true;
        uint32_t base = j * m_num_features * 2;

        for (uint32_t k = 0; k < m_num_features; k++) {
            int32_t action_include = ta_action(m_ta_state[base + k * 2 + 0]);
            int32_t action_include_negated = ta_action(m_ta_state[base + k * 2 + 1]);

            if (action_include == 1 || action_include_negated == 1) {
                all_exclude = false;
            }

            // Literal violation: included literal doesn't match input
            if ((action_include == 1 && X[k] == 0) ||
                (action_include_negated == 1 && X[k] == 1)) {
                m_clause_output[j] = 0;
                break;
            }
        }

        // In predict mode, all-excluded clauses are inactive
        if (predict_mode && all_exclude) {
            m_clause_output[j] = 0;
        }
    }
}

/* -------------------------------------------------------------------------
 * Sum up votes per class
 * class_sum[action] = Σ clause_output[clause] * polarity
 * Clamped to [-threshold, +threshold]
 * ------------------------------------------------------------------------- */
void TsetlinMachine::sum_up_class_votes() {
    for (uint32_t a = 0; a < m_num_actions; a++) {
        m_class_sum[a] = 0;
    }

    for (uint32_t j = 0; j < m_num_clauses; j++) {
        uint32_t action = m_clause_info[j].action_class;
        m_class_sum[action] += m_clause_output[j] * m_clause_info[j].polarity;
    }

    // Clamp to threshold
    for (uint32_t a = 0; a < m_num_actions; a++) {
        if (m_class_sum[a] > m_threshold)  m_class_sum[a] = m_threshold;
        if (m_class_sum[a] < -m_threshold) m_class_sum[a] = -m_threshold;
    }
}

/* -------------------------------------------------------------------------
 * predict(): return the action with highest vote sum
 * ------------------------------------------------------------------------- */
uint32_t TsetlinMachine::predict(const int32_t* features) {
    calculate_clause_output(features, true);
    sum_up_class_votes();

    int32_t max_sum = m_class_sum[0];
    uint32_t best_action = 0;

    for (uint32_t a = 1; a < m_num_actions; a++) {
        if (m_class_sum[a] > max_sum) {
            max_sum = m_class_sum[a];
            best_action = a;
        }
    }

    return best_action;
}

/* -------------------------------------------------------------------------
 * update(): online training via Type I / Type II feedback
 *
 * If is_positive:
 *   - target_action gets Type I feedback (reinforce pattern)
 *   - random other action gets Type II feedback (discriminate against it)
 * If !is_positive:
 *   - target_action gets Type II feedback (penalize)
 *   - random other action gets Type I feedback (explore alternative)
 * ------------------------------------------------------------------------- */
void TsetlinMachine::update(const int32_t* features, uint32_t target_action, bool is_positive) {
    // Pick a random "other" action for pairwise learning.
    // When there is only one action class, pairwise discrimination is meaningless
    // — just apply target-only feedback without a negative counterpart.
    uint32_t negative_action = target_action;
    bool has_negative = (m_num_actions > 1);
    if (has_negative) {
        do {
            negative_action = m_neg_dist(m_rng);
        } while (negative_action == target_action);
    }

    // Compute clause outputs and class sums
    calculate_clause_output(features, false);
    sum_up_class_votes();

    // Clear feedback array
    for (uint32_t j = 0; j < m_num_clauses; j++) {
        m_feedback_to_clauses[j] = 0;
    }

    // ---- Feedback for target action's clauses ----
    if (is_positive) {
        // Positive: target gets Type I, negative target gets Type II (standard multiclass)
        for (uint32_t j = m_action_clause_start[target_action];
             j < m_action_clause_start[target_action] + m_clauses_per_action; j++) {
            if (skip_feedback((float)m_class_sum[target_action], 1)) continue;
            m_feedback_to_clauses[j] = (m_clause_info[j].polarity >= 0) ? 1 : -1;
        }
        if (has_negative) {
            for (uint32_t j = m_action_clause_start[negative_action];
                 j < m_action_clause_start[negative_action] + m_clauses_per_action; j++) {
                if (skip_feedback((float)m_class_sum[negative_action], -1)) continue;
                m_feedback_to_clauses[j] = (m_clause_info[j].polarity >= 0) ? -1 : 1;
            }
        }
    } else {
        // Negative: target gets Type II, other gets Type I (learn to avoid target)
        for (uint32_t j = m_action_clause_start[target_action];
             j < m_action_clause_start[target_action] + m_clauses_per_action; j++) {
            if (skip_feedback((float)m_class_sum[target_action], -1)) continue;
            m_feedback_to_clauses[j] = (m_clause_info[j].polarity >= 0) ? -1 : 1;
        }
        if (has_negative) {
            for (uint32_t j = m_action_clause_start[negative_action];
                 j < m_action_clause_start[negative_action] + m_clauses_per_action; j++) {
                if (skip_feedback((float)m_class_sum[negative_action], 1)) continue;
                m_feedback_to_clauses[j] = (m_clause_info[j].polarity >= 0) ? 1 : -1;
            }
        }
    }

    // ---- Apply feedback to individual automata ----
    for (uint32_t j = 0; j < m_num_clauses; j++) {
        if (m_feedback_to_clauses[j] > 0) {
            type_I_feedback(j, features);
        } else if (m_feedback_to_clauses[j] < 0) {
            type_II_feedback(j, features);
        }
    }
}

/* -------------------------------------------------------------------------
 * Resource allocation: skip feedback based on vote margin
 * Probability of feedback = (T - |class_sum|) / (2T)
 * When sum approaches T → probability → 0 (clause has enough votes)
 * ------------------------------------------------------------------------- */
bool TsetlinMachine::skip_feedback(float class_sum_val, int32_t polarity) {
    float margin;
    if (polarity > 0) {
        // For target class (we want high positive sum)
        margin = (float)(m_threshold - class_sum_val) / (2.0f * m_threshold);
    } else {
        // For negative class (we want low/negative sum)
        margin = (float)(m_threshold + class_sum_val) / (2.0f * m_threshold);
    }

    if (margin <= 0.0f) return true;
    return m_dist(m_rng) > margin;
}

/* -------------------------------------------------------------------------
 * Type I Feedback: Combats false negatives, produces frequent patterns
 *
 * When clause_output == 0:
 *   - With probability 1/s: decrement both automata (weaken exclusion)
 *   - This makes the clause more likely to fire in the future
 *
 * When clause_output == 1:
 *   - If X[k] == 1: with prob (s-1)/s increment include automaton;
 *                   with prob 1/s decrement negated automaton
 *   - If X[k] == 0: with prob (s-1)/s increment negated automaton;
 *                   with prob 1/s decrement include automaton
 *   - This reinforces the current pattern match
 * ------------------------------------------------------------------------- */
void TsetlinMachine::type_I_feedback(uint32_t clause_idx, const int32_t* X) {
    uint32_t base = clause_idx * m_num_features * 2;

    if (m_clause_output[clause_idx] == 0) {
        // Clause didn't fire → weaken exclusions so it fires more easily
        for (uint32_t k = 0; k < m_num_features; k++) {
            uint32_t idx_inc = base + k * 2 + 0;
            uint32_t idx_neg = base + k * 2 + 1;

            if (m_dist(m_rng) <= 1.0f / m_s) {
                if (m_ta_state[idx_inc] > 1)
                    m_ta_state[idx_inc] -= 1;
            }
            if (m_dist(m_rng) <= 1.0f / m_s) {
                if (m_ta_state[idx_neg] > 1)
                    m_ta_state[idx_neg] -= 1;
            }
        }
    } else {
        // Clause fired → reinforce the pattern
        for (uint32_t k = 0; k < m_num_features; k++) {
            uint32_t idx_inc = base + k * 2 + 0;
            uint32_t idx_neg = base + k * 2 + 1;
            uint32_t max_state = m_num_states * 2;

            if (X[k] == 1) {
                // Feature is 1 → promote include, demote negated
                if (m_dist(m_rng) <= (m_s - 1.0f) / m_s) {
                    if (m_ta_state[idx_inc] < max_state)
                        m_ta_state[idx_inc] += 1;
                }
                if (m_dist(m_rng) <= 1.0f / m_s) {
                    if (m_ta_state[idx_neg] > 1)
                        m_ta_state[idx_neg] -= 1;
                }
            } else { // X[k] == 0
                // Feature is 0 → promote negated, demote include
                if (m_dist(m_rng) <= (m_s - 1.0f) / m_s) {
                    if (m_ta_state[idx_neg] < max_state)
                        m_ta_state[idx_neg] += 1;
                }
                if (m_dist(m_rng) <= 1.0f / m_s) {
                    if (m_ta_state[idx_inc] > 1)
                        m_ta_state[idx_inc] -= 1;
                }
            }
        }
    }
}

/* -------------------------------------------------------------------------
 * Type II Feedback: Combats false positives, increases discrimination
 *
 * Only applies when clause_output == 1:
 *   - If X[k] == 0 AND include action == EXCLUDE: increment include (make it INCLUDE)
 *   - If X[k] == 1 AND negated action == EXCLUDE: increment negated
 *   - This introduces literals that will make the clause NOT fire for this input
 * ------------------------------------------------------------------------- */
void TsetlinMachine::type_II_feedback(uint32_t clause_idx, const int32_t* X) {
    if (m_clause_output[clause_idx] != 1) return;

    uint32_t base = clause_idx * m_num_features * 2;
    uint32_t max_state = m_num_states * 2;

    for (uint32_t k = 0; k < m_num_features; k++) {
        uint32_t idx_inc = base + k * 2 + 0;
        uint32_t idx_neg = base + k * 2 + 1;

        if (X[k] == 0) {
            // Feature is 0 but clause fired → need to include this literal
            // If currently excluded, move toward include
            if (ta_action(m_ta_state[idx_inc]) == 0 && m_ta_state[idx_inc] < max_state) {
                m_ta_state[idx_inc] += 1;
            }
        } else { // X[k] == 1
            // Feature is 1 but clause fired → need to include negated
            if (ta_action(m_ta_state[idx_neg]) == 0 && m_ta_state[idx_neg] < max_state) {
                m_ta_state[idx_neg] += 1;
            }
        }
    }
}

int32_t TsetlinMachine::get_class_sum(uint32_t action_class) const {
    return m_class_sum[action_class];
}

int32_t TsetlinMachine::get_second_best_class_sum() const {
    if (m_num_actions <= 1) return 0;

    int32_t best = m_class_sum[0];
    int32_t second = INT32_MIN;

    // First pass: find the maximum
    for (uint32_t a = 1; a < m_num_actions; a++) {
        if (m_class_sum[a] > best) best = m_class_sum[a];
    }

    // Second pass: find the maximum that is strictly less than best
    bool found = false;
    for (uint32_t a = 0; a < m_num_actions; a++) {
        if (m_class_sum[a] < best && m_class_sum[a] > second) {
            second = m_class_sum[a];
            found = true;
        }
    }

    return found ? second : best;  // fallback if all equal (cold start)
}

void TsetlinMachine::dump_state() const {
    cout << "=== Tsetlin Machine State ===" << endl;
    cout << "clauses=" << m_num_clauses << " features=" << m_num_features
         << " actions=" << m_num_actions << " states=" << m_num_states
         << " s=" << m_s << " T=" << m_threshold << endl;

    // Count how many automata are in INCLUDE state
    size_t total_include = 0, total_states = m_num_clauses * m_num_features * 2;
    for (size_t i = 0; i < total_states; i++) {
        if (ta_action(m_ta_state[i]) == 1) total_include++;
    }
    cout << "total TA states=" << total_states
         << " include=" << total_include
         << " exclude=" << (total_states - total_include)
         << " include_ratio=" << fixed << setprecision(2)
         << (100.0 * total_include / total_states) << "%" << endl;
}


/* =========================================================================
 * TsetlinPrefetcher Implementation
 * ========================================================================= */

TsetlinPrefetcher::TsetlinPrefetcher(
        const TsetlinMachine::Config& tm_cfg,
        const vector<int32_t>& actions,
        uint32_t pt_size, uint32_t pref_degree,
        float epsilon, uint8_t high_bw_thresh,
        uint64_t seed, string type,
        bool enable_dyn_degree,
        const vector<int32_t>& dyn_deg_thresh,
        const vector<int32_t>& dyn_deg_values,
        const vector<int32_t>& dyn_deg_thresh_hbw,
        const vector<int32_t>& dyn_deg_values_hbw,
        uint32_t temp_delta_bits,
        uint32_t interaction_bits,
        uint32_t temp_bw_bits,
        uint32_t delta_sig_bits,
        uint32_t freq_bits,
        uint32_t conf_bits,
        float epsilon_init,
        uint64_t warmup_invocations)
    : Prefetcher(type)
    , m_num_features(tm_cfg.num_features)
    , m_actions(actions)
    , m_max_actions((uint32_t)actions.size())
    , m_pt_size(pt_size)
    , m_bw_level(0)
    , m_high_bw_thresh(high_bw_thresh)
    , m_pref_degree(pref_degree)
    , m_enable_dyn_degree(enable_dyn_degree)
    , m_dyn_deg_thresh(dyn_deg_thresh)
    , m_dyn_deg_values(dyn_deg_values)
    , m_dyn_deg_thresh_hbw(dyn_deg_thresh_hbw)
    , m_dyn_deg_values_hbw(dyn_deg_values_hbw)
    , m_epsilon_init(epsilon_init)
    , m_epsilon_min(epsilon)
    , m_warmup_invocations(warmup_invocations)
    , m_invocation_count(0)
    , m_rng(seed)
    , m_explore(epsilon_init > epsilon ? epsilon_init : epsilon)  // start at init rate
    , m_action_gen(0, m_max_actions - 1)
{
    // Create the Tsetlin Machine
    m_tm = new TsetlinMachine(tm_cfg);

    // invoke_prefetcher() uses a stack-allocated features[MAX_FEATURES] buffer
    // on the hot path to avoid heap allocation. Assert the bound holds.
    assert(m_num_features <= MAX_FEATURES &&
           "features buffer in invoke_prefetcher() limited to MAX_FEATURES");

    // Initialize last-offset tracking table
    for (uint32_t i = 0; i < LAST_OFFSET_TABLE_SIZE; i++) {
        m_last_offset_table[i].valid = false;
        m_last_offset_table[i].page_tag = 0;
        m_last_offset_table[i].last_offset = -1;
    }

    // ---- Enhanced feature bit allocation (P1.4: +freq/conf) ----
    // Layout with 80-bit default (freq_bits=0, conf_bits=0):
    //   [0..hash_bits-1]:             hash(PC, page) — 41 bits
    //   [hash_bits..+7]:              thermometer(offset) — 8 bits
    //   [hash_bits+8..+8+delta-1]:    thermometer(|delta|) — 12 bits
    //   [hash_bits+8+delta]:          delta sign — 1 bit
    //   [..]:                          PC×Page interaction hash — 4 bits
    //   [..]:                          thermometer(bw_level) — 2 bits
    //   [..]:                          delta signature bitwise — 12 bits (P1.3)
    //   [..]:                          thermometer(access_count) — 0-8 bits (P1.4)
    //   [..]:                          thermometer(last_confidence) — 0-8 bits (P1.4)
    m_temp_offset_bits = 8;
    m_temp_delta_bits  = (temp_delta_bits >= 8) ? temp_delta_bits : 8;
    m_interaction_bits = interaction_bits;
    m_temp_bw_bits     = temp_bw_bits;
    m_delta_sig_bits   = (delta_sig_bits <= DELTA_SIG_BIT) ? delta_sig_bits : DELTA_SIG_BIT;
    m_freq_bits        = (freq_bits <= 8) ? freq_bits : 8;    // max 8 bits (256 levels)
    m_conf_bits        = (conf_bits <= 8) ? conf_bits : 8;    // max 8 bits
    m_tm_threshold     = (int32_t)tm_cfg.threshold;           // for confidence max

    uint32_t min_features = m_temp_offset_bits + m_temp_delta_bits + 1
                          + m_interaction_bits + m_temp_bw_bits
                          + m_delta_sig_bits + m_freq_bits + m_conf_bits;
    assert(m_num_features >= min_features &&
           "num_features too small for configured feature bit allocation");
    m_hash_feature_bits = m_num_features - m_temp_offset_bits
                        - m_temp_delta_bits - 1
                        - m_interaction_bits - m_temp_bw_bits
                        - m_delta_sig_bits - m_freq_bits - m_conf_bits;

    // Initialize stats (zero-init scalars; vectors resized below)
    m_stats.pt.lookup = 0; m_stats.pt.hit = 0; m_stats.pt.evict = 0; m_stats.pt.insert = 0;
    m_stats.predict.called = 0; m_stats.predict.explore = 0; m_stats.predict.exploit = 0;
    m_stats.predict.out_of_bounds = 0; m_stats.predict.predicted = 0;
    m_stats.predict.multi_deg_called = 0; m_stats.predict.multi_deg_issued = 0;
    m_stats.reward.called = 0; m_stats.reward.pt_not_found = 0; m_stats.reward.pt_found = 0;
    m_stats.reward.correct_timely = 0; m_stats.reward.correct_untimely = 0;
    m_stats.reward.incorrect = 0; m_stats.reward.no_pref = 0;
    m_stats.learn.called = 0; m_stats.learn.learned_positive = 0;
    m_stats.learn.learned_negative = 0; m_stats.learn.learn_skipped_no_reward = 0;
    m_stats.register_fill.called = 0; m_stats.register_fill.set = 0;

    m_stats.predict.action_dist.resize(m_max_actions, 0);
    m_stats.predict.issue_dist.resize(m_max_actions, 0);
    // Dynamic degree histograms: size = max possible degree + 1 (index by degree)
    uint32_t max_deg = m_pref_degree > 0 ? m_pref_degree : 6;
    m_stats.predict.deg_histogram.resize(max_deg + 1, 0);
    m_stats.predict.multi_deg_histogram.resize(max_deg + 1, 0);
    for (int i = 0; i < NUM_REWARD_TYPES; i++) {
        m_stats.reward.reward_per_action[i].resize(m_max_actions, 0);
    }
}

TsetlinPrefetcher::~TsetlinPrefetcher() {
    delete m_tm;
    // Clean up any remaining PT entries
    while (!m_pt.empty()) {
        delete m_pt.back();
        m_pt.pop_back();
    }
}

/* -------------------------------------------------------------------------
 * Feature Generation: Program state → Binary feature vector (P1.4: +freq/conf)
 *
 * HYBRID ENCODING SCHEME (80-bit default, extendable via freq/conf bits):
 * - Categorical features (PC, page) → XOR-based hashing
 * - Ordinal features (offset, delta, bw, access_count, confidence) → thermometer
 * - Hash features (PC×Page interaction, delta signature) → bitwise/hash
 *
 * Feature layout (80+ bits):
 *   [hash]                               : hash(PC, page) — remainder bits
 *   [..+7]                               : thermometer(offset, 8 bits)
 *   [..+delta_bits-1]                    : thermometer(|delta|, 12 bits)
 *   [..]                                 : delta sign — 1 bit
 *   [..+interaction_bits-1]              : PC×Page interaction hash — 4 bits
 *   [..+bw_bits-1]                       : thermometer(bw_level) — 2 bits
 *   [..+delta_sig_bits-1]                : bitwise(delta_sig) — 12 bits (P1.3)
 *   [..+freq_bits-1]                     : thermometer(access_count) — 0-8 bits (P1.4)
 *   [..+conf_bits-1]                     : thermometer(last_confidence) — 0-8 bits (P1.4)
 *
 * All operations are integer bitwise or comparisons → hardware-friendly.
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::generate_features(
        uint64_t pc, uint64_t page, uint32_t offset,
        int32_t delta, uint8_t bw_level, uint32_t delta_sig,
        uint32_t access_count, int32_t last_confidence, int32_t* features)
{
    // ---- Part 1: Hash encoding for categorical features (PC, page) ----
    // BW level is no longer mixed into the hash — it gets its own
    // independent thermometer encoding below (P1.2).
    uint64_t base = pc;
    base ^= (page << 3);

    for (uint32_t i = 0; i < m_hash_feature_bits; i++) {
        uint64_t h = base ^ ((uint64_t)i * 0x9E3779B97F4A7C15ULL);

        // splitmix64 mixing (all integer ops)
        h = (h ^ (h >> 30)) * 0xBF58476D1CE4E5B9ULL;
        h = (h ^ (h >> 27)) * 0x94D049BB133111EBULL;
        h = h ^ (h >> 31);

        features[i] = (int32_t)(h & 1);
    }

    uint32_t feat_base = m_hash_feature_bits;

    // ---- Part 2: Thermometer encoding for block offset [0, 63] ----
    for (uint32_t i = 0; i < m_temp_offset_bits; i++) {
        int32_t threshold = (int32_t)((i + 1) * 63 / m_temp_offset_bits);
        features[feat_base + i] = ((int32_t)offset >= threshold) ? 1 : 0;
    }

    // ---- Part 3: Thermometer encoding for delta magnitude (P1.2: 12 bits) ----
    // Finer resolution (12 vs 8 thresholds) distinguishes strides like +3 vs +4
    // that previously mapped to the same coarse bucket. Delta range is [-63, +63].
    uint32_t delta_mag = (uint32_t)((delta < 0) ? (-delta) : delta);
    feat_base += m_temp_offset_bits;
    for (uint32_t i = 0; i < m_temp_delta_bits; i++) {
        int32_t threshold = (int32_t)((i + 1) * 63 / m_temp_delta_bits);
        features[feat_base + i] = ((int32_t)delta_mag >= threshold) ? 1 : 0;
    }

    // ---- Part 4: Delta sign bit ----
    feat_base += m_temp_delta_bits;
    features[feat_base] = (delta >= 0) ? 1 : 0;

    // ---- Part 5: PC×Page interaction hash (P1.2 NEW) ----
    // Captures joint (PC, page) identity — different from the sum of individual
    // hashes because the interaction encodes which PC operates on which page.
    // This was the #1 missing feature vs LinUCB's feature [6].
    feat_base += 1;  // skip sign bit
    if (m_interaction_bits > 0) {
        uint64_t interaction_base = pc ^ (page << 7) ^ 0xA5A5A5A5A5A5A5A5ULL;
        for (uint32_t i = 0; i < m_interaction_bits; i++) {
            uint64_t h = interaction_base ^ ((uint64_t)i * 0x9E3779B97F4A7C15ULL);
            h = (h ^ (h >> 30)) * 0xBF58476D1CE4E5B9ULL;
            h = (h ^ (h >> 27)) * 0x94D049BB133111EBULL;
            h = h ^ (h >> 31);
            features[feat_base + i] = (int32_t)(h & 1);
        }
    }
    feat_base += m_interaction_bits;  // unconditionally skip interaction region

    // ---- Part 6: Thermometer encoding for BW level (P1.2 NEW) ----
    // DRAM_BW_LEVELS = 4 (0=idle, 1=low, 2=medium, 3=high).
    // Independent encoding so the TM can learn BW-aware rules like
    // "if BW is high AND stride is small → don't prefetch".
    if (m_temp_bw_bits > 0) {
        uint32_t bw_max = 3;  // DRAM_BW_LEVELS - 1
        for (uint32_t i = 0; i < m_temp_bw_bits; i++) {
            int32_t threshold = (int32_t)((i + 1) * bw_max / m_temp_bw_bits);
            features[feat_base + i] = ((int32_t)bw_level >= threshold) ? 1 : 0;
        }
    }
    feat_base += m_temp_bw_bits;  // unconditionally skip BW region (P1.3 fix)

    // ---- Part 7: Delta signature bitwise encoding (P1.3 NEW) ----
    // The delta signature is a 12-bit shift-XOR hash of the last 4 deltas.
    // Since it's a hash value with no ordinal semantics (sig=0x1F and sig=0x20
    // are semantically unrelated despite being numerically adjacent), we MUST
    // use bitwise encoding (each bit is an independent feature) rather than
    // thermometer encoding.  The TM learns which bit combinations correspond
    // to specific delta-history patterns.
    //
    // Only the low DELTA_SIG_BIT bits of delta_sig carry information; higher
    // bits are always zero (masked by DELTA_SIG_MASK).
    if (m_delta_sig_bits > 0) {
        for (uint32_t i = 0; i < m_delta_sig_bits; i++) {
            features[feat_base + i] = (int32_t)((delta_sig >> i) & 1u);
        }
    }
    feat_base += m_delta_sig_bits;  // unconditionally skip delta_sig region

    // ---- Part 8: Access frequency thermometer encoding (P1.4 NEW) ----
    // Per-page access count (saturating 8-bit counter, 0..255).  Hot pages may
    // have different prefetch behavior than cold pages — the TM can learn rules
    // like "if page is hot AND stride is large → multi-degree prefetch".
    // Disabled by default (m_freq_bits=0); set to 4-8 to enable.
    if (m_freq_bits > 0) {
        uint32_t freq_max = 255;  // saturating 8-bit counter
        for (uint32_t i = 0; i < m_freq_bits; i++) {
            int32_t threshold = (int32_t)((i + 1) * freq_max / m_freq_bits);
            features[feat_base + i] = ((int32_t)access_count >= threshold) ? 1 : 0;
        }
    }
    feat_base += m_freq_bits;  // unconditionally skip freq region

    // ---- Part 9: Confidence feedback thermometer encoding (P1.4 NEW) ----
    // The TM's own vote margin from the last prediction on this page, fed back
    // as input for the current prediction.  This enables "second-order reasoning":
    // the TM can learn rules conditioned on its own certainty, e.g.:
    //   "IF delta_sig matches AND confidence_was_high → prefetch aggressively"
    //   "IF delta_sig matches AND confidence_was_low  → be conservative"
    // Disabled by default (m_conf_bits=0); set to 3-5 to enable.
    if (m_conf_bits > 0) {
        int32_t conf_max = 2 * m_tm_threshold;  // max vote margin [0, 2T]
        for (uint32_t i = 0; i < m_conf_bits; i++) {
            int32_t threshold = (int32_t)((i + 1) * conf_max / m_conf_bits);
            features[feat_base + i] = (last_confidence >= threshold) ? 1 : 0;
        }
    }
}

/* -------------------------------------------------------------------------
 * invoke_prefetcher(): Main entry point, called on every demand request
 *
 * Flow:
 * 1. Compute reward for previously tracked prefetches (on-demand check)
 * 2. Extract program state (page, offset, delta)
 * 3. Generate binary features from state
 * 4. TM predict → action index
 * 5. If action != 0: generate prefetch addresses, track in PT
 * 6. If action == 0: track no-prefetch decision (for later reward)
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::invoke_prefetcher(
        uint64_t pc, uint64_t address, uint8_t cache_hit,
        uint8_t type, vector<uint64_t>& pref_addr)
{
    uint64_t page   = address >> LOG2_PAGE_SIZE;
    uint32_t offset = (address >> LOG2_BLOCK_SIZE) &
                      ((1ull << (LOG2_PAGE_SIZE - LOG2_BLOCK_SIZE)) - 1);

    // ---- Step 1: Compute reward for previous prefetches ----
    {
        m_stats.reward.called++;
        vector<TMPrefetchTrackerEntry*> matches = search_pt(address);
        if (!matches.empty()) {
            m_stats.reward.pt_found++;
            for (auto* entry : matches) {
                if (entry->has_reward) continue;

                if (entry->is_filled) {
                    entry->reward_type = REWARD_TIMELY;
                    m_stats.reward.correct_timely++;
                } else {
                    entry->reward_type = REWARD_UNTIMELY;
                    m_stats.reward.correct_untimely++;
                }
                entry->reward = compute_reward(entry, entry->reward_type);
                entry->has_reward = true;

                // Train TM
                train_from_reward(entry);
            }
        } else {
            m_stats.reward.pt_not_found++;
        }
    }

    // ---- Step 2: Compute real delta from last-offset tracking table ----
    // Also maintains delta signature (P1.3), access count (P1.4), and
    // confidence feedback (P1.4).
    uint32_t lot_idx = (uint32_t)(page & (LAST_OFFSET_TABLE_SIZE - 1));
    LastOffsetEntry& lot_entry = m_last_offset_table[lot_idx];

    int32_t delta = 0;
    uint32_t delta_sig = 0;
    uint32_t access_count = 0;
    int32_t  last_confidence = 0;

    if (lot_entry.valid && lot_entry.page_tag == page) {
        // Hit: same page as last access → compute true stride
        delta = (int32_t)offset - lot_entry.last_offset;

        // SPP-style delta signature update (P1.3)
        int sig_delta = (delta < 0)
            ? ((-delta) + (1 << (SPP_DELTA_ENC_BIT - 1)))
            : delta;
        lot_entry.delta_sig = ((lot_entry.delta_sig << DELTA_SIG_SHIFT)
                               ^ (uint32_t)sig_delta) & DELTA_SIG_MASK;
        lot_entry.delta_count++;

        // P1.4: increment access count (saturating 8-bit counter)
        if (lot_entry.access_count < 255) {
            lot_entry.access_count++;
        }
    } else {
        // First access to this page or page collision: reset all
        // page-specific tracking fields to avoid leaking state from
        // the previous page that occupied this slot.
        lot_entry.access_count = 1;
        lot_entry.delta_sig = 0;
        lot_entry.last_confidence = 0;
    }
    // Snapshot current values for feature generation
    delta_sig = lot_entry.delta_sig;
    access_count = lot_entry.access_count;
    last_confidence = lot_entry.last_confidence;  // from LAST prediction (P1.4)

    // Always update the table for next access (within-page stride tracking)
    lot_entry.page_tag = page;
    lot_entry.last_offset = (int32_t)offset;
    lot_entry.valid = true;

    // ---- Step 3: Generate features ----
    // Stack-allocated to avoid heap allocation on the hot path (every demand
    // request).  MAX_FEATURES is a generous upper bound; the constructor
    // asserts m_num_features <= MAX_FEATURES.
    int32_t features[MAX_FEATURES];
    generate_features(pc, page, offset, delta, m_bw_level, delta_sig,
                      access_count, last_confidence, features);

    // ---- Step 4: Predict action ----
    m_stats.predict.called++;

    // ---- ε-greedy annealing (P2.2) ----
    // Start with higher exploration (m_epsilon_init) and linearly decay to
    // the configured floor (m_epsilon_min) over m_warmup_invocations.
    // This helps the TM escape the cold-start local optimum where negative
    // feedback dominates — more exploration early means more chances to
    // discover positive reward patterns.
    if (m_invocation_count < m_warmup_invocations) {
        float progress = (float)m_invocation_count / (float)m_warmup_invocations;
        float current_eps = m_epsilon_init - (m_epsilon_init - m_epsilon_min) * progress;
        m_explore = std::bernoulli_distribution(current_eps);
    }
    m_invocation_count++;

    uint32_t action_index;

    if (m_explore(m_rng)) {
        // ε-exploration: random action
        action_index = m_action_gen(m_rng);
        m_stats.predict.explore++;
    } else {
        // Exploit: use TM prediction
        action_index = m_tm->predict(features);
        m_stats.predict.exploit++;
    }

    assert(action_index < m_max_actions);

    // ---- P1.4: Store confidence for next prediction on this page ----
    // Enables second-order reasoning: the TM's own certainty becomes a feature
    // for the next decision on the same page.  Confidence = vote margin.
    if (m_conf_bits > 0) {
        int32_t best_sum   = m_tm->get_class_sum(action_index);
        int32_t second_sum = m_tm->get_second_best_class_sum();
        int32_t conf = best_sum - second_sum;
        if (conf < 0) conf = 0;
        lot_entry.last_confidence = conf;
    }

    // ---- Step 5: Issue prefetch or track no-prefetch ----
    uint32_t count_before = pref_addr.size();

    if (m_actions[action_index] != 0) {
        // Issue a prefetch
        int32_t predicted_offset = (int32_t)offset + m_actions[action_index];
        int32_t max_offset = (1 << (LOG2_PAGE_SIZE - LOG2_BLOCK_SIZE)) - 1;

        if (predicted_offset >= 0 && predicted_offset <= max_offset) {
            uint64_t pf_addr = (page << LOG2_PAGE_SIZE) +
                               (predicted_offset << LOG2_BLOCK_SIZE);

            // Check if already tracked (avoid duplicates)
            vector<TMPrefetchTrackerEntry*> existing = search_pt(pf_addr);
            if (existing.empty()) {
                pref_addr.push_back(pf_addr);
                m_stats.predict.issue_dist[action_index]++;

                // Track in PT
                TMPrefetchTrackerEntry* entry =
                    new TMPrefetchTrackerEntry(pf_addr, features,
                                                action_index, m_num_features);
                m_pt.push_back(entry);
                m_stats.pt.insert++;

                // Evict oldest if PT is full
                if (m_pt.size() > m_pt_size) {
                    TMPrefetchTrackerEntry* victim = m_pt.front();
                    m_pt.pop_front();
                    m_stats.pt.evict++;
                    // Track PT pressure: filled=true means the data arrived
                    // but was evicted before the demand access → PT undersized.
                    // unfilled means the data never arrived → likely a bad prefetch.
                    if (victim->is_filled) { m_stats.pt.evict_filled++; }
                    else                   { m_stats.pt.evict_unfilled++; }

                    // Compute reward for evicted entry (incorrect or no_pref)
                    if (!victim->has_reward) {
                        if (victim->address == 0xdeadbeef) {
                            victim->reward_type = REWARD_NONE;
                            m_stats.reward.no_pref++;
                        } else {
                            victim->reward_type = REWARD_INCORRECT;
                            m_stats.reward.incorrect++;
                        }
                        victim->reward = compute_reward(victim, victim->reward_type);
                        victim->has_reward = true;
                        train_from_reward(victim);
                    }
                    delete victim;
                }

                // ---- Dynamic multi-degree prefetch ----
                // If enabled, issue extra speculative prefetches based on
                // TM vote confidence. Only the base (degree-1) prefetch is
                // PT-tracked; extra prefetches are speculative bonuses.
                uint32_t dyn_degree = get_dyn_pref_degree(action_index);
                m_stats.predict.deg_histogram[dyn_degree]++;
                if (dyn_degree > 1) {
                    gen_multi_degree_pref(page, offset,
                                          m_actions[action_index],
                                          dyn_degree, pref_addr);
                }
            }
        } else {
            // Out-of-bounds: the chosen action would cross a page boundary.
            // Create a PT entry so the TM receives complete feedback —
            // otherwise this (state, action) pair is a learning blind spot
            // (never rewarded or penalized).  Out-of-bounds entries are
            // treated as incorrect on eviction: the action was invalid.
            m_stats.predict.out_of_bounds++;
            TMPrefetchTrackerEntry* entry =
                new TMPrefetchTrackerEntry(0xdeadbeef, features,
                                            action_index, m_num_features);
            m_pt.push_back(entry);
            m_stats.pt.insert++;

            if (m_pt.size() > m_pt_size) {
                TMPrefetchTrackerEntry* victim = m_pt.front();
                m_pt.pop_front();
                m_stats.pt.evict++;
                if (victim->is_filled) { m_stats.pt.evict_filled++; }
                else                   { m_stats.pt.evict_unfilled++; }

                if (!victim->has_reward) {
                    // Out-of-bounds action → always incorrect (no useful prefetch)
                    victim->reward_type = REWARD_INCORRECT;
                    m_stats.reward.incorrect++;
                    victim->reward = compute_reward(victim, victim->reward_type);
                    victim->has_reward = true;
                    train_from_reward(victim);
                }
                delete victim;
            }
        }
    } else {
        // No prefetch: track decision
        TMPrefetchTrackerEntry* entry =
            new TMPrefetchTrackerEntry(0xdeadbeef, features,
                                        action_index, m_num_features);
        m_pt.push_back(entry);
        m_stats.pt.insert++;

        if (m_pt.size() > m_pt_size) {
            TMPrefetchTrackerEntry* victim = m_pt.front();
            m_pt.pop_front();
            m_stats.pt.evict++;
            if (victim->is_filled) { m_stats.pt.evict_filled++; }
            else                   { m_stats.pt.evict_unfilled++; }

            if (!victim->has_reward) {
                victim->reward_type = REWARD_NONE;
                m_stats.reward.no_pref++;
                victim->reward = compute_reward(victim, victim->reward_type);
                victim->has_reward = true;
                train_from_reward(victim);
            }
            delete victim;
        }
    }

    m_stats.predict.action_dist[action_index]++;
    m_stats.predict.predicted += (pref_addr.size() - count_before);
    // features[] is stack-allocated — no delete needed.
}

/* -------------------------------------------------------------------------
 * register_fill(): Called when a prefetched line is filled into the cache
 * Marks the corresponding PT entry as filled → used for timeliness check
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::register_fill(uint64_t address) {
    m_stats.register_fill.called++;
    vector<TMPrefetchTrackerEntry*> matches = search_pt(address);

    for (auto* entry : matches) {
        entry->is_filled = true;
        m_stats.register_fill.set++;
    }
}

/* -------------------------------------------------------------------------
 * register_prefetch_hit(): Called when a prefetched line is found in cache
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::register_prefetch_hit(uint64_t address) {
    // Prefetch already in cache → extremely late, but still a hit
    // We don't modify reward here; it's handled in invoke_prefetcher
}

/* -------------------------------------------------------------------------
 * Search PT for entries matching the given address
 * ------------------------------------------------------------------------- */
vector<TMPrefetchTrackerEntry*> TsetlinPrefetcher::search_pt(uint64_t address) {
    m_stats.pt.lookup++;
    vector<TMPrefetchTrackerEntry*> result;
    for (auto* entry : m_pt) {
        // NOTE: address must be block-aligned (cache-line granularity) by the
        // ChampSim framework. If the caller passes a raw byte address with
        // sub-block offset bits set, this exact-match comparison will fail
        // and the PT will appear empty, breaking the reward feedback loop.
        if (entry->address == address && !entry->has_reward) {
            result.push_back(entry);
        }
    }
    if (!result.empty()) {
        m_stats.pt.hit++;
    }
    return result;
}

/* -------------------------------------------------------------------------
 * Compute reward value based on type and bandwidth state
 * ------------------------------------------------------------------------- */
int32_t TsetlinPrefetcher::compute_reward(
        TMPrefetchTrackerEntry* entry, int32_t reward_type)
{
    // Reward values (similar to Pythia's defaults)
    // High BW: more aggressive penalization for incorrect prefetches
    bool high_bw = is_high_bw();

    switch (reward_type) {
        // High BW: good prefetches are more valuable (saved BW in a tight channel)
        case REWARD_TIMELY:    return high_bw ? 25 : 20;
        // High BW: late prefetches are more harmful (wasted BW when it's scarce)
        case REWARD_UNTIMELY:  return high_bw ?  6 : 10;
        // P2.1: INCORRECT is split by is_filled.
        // - filled=true:  data arrived but PT window too short → mild penalty
        //                  (the prefetch was useful, tracking just failed)
        // - filled=false: data never arrived → true incorrect → full penalty
        case REWARD_INCORRECT:
            if (entry->is_filled) {
                return high_bw ? -8 : -4;   // PT pressure, not truly bad
            } else {
                return high_bw ? -16 : -8;  // genuinely useless prefetch
            }
        // No-prefetch decisions age out without any demand access hitting the
        // would-be-prefetched location.  Return 0 (neutral) to avoid creating a
        // systematic bias against action 0.
        case REWARD_NONE:      return 0;
        default:               return 0;
    }
}

/* -------------------------------------------------------------------------
 * Train TM from a PT entry's reward
 *
 * Reward mapping to TM training:
 * - Timely/Untimely (>0): positive feedback → Type I for chosen action
 * - Incorrect (<0): negative feedback → Type II for chosen action
 * - None (action=0): treat as correct restraint → Type I for action 0
 *   (the PT entry aged out without any demand access hitting the
 *    would-be-prefetched location — being conservative was the right call)
 * - None (action!=0): this case should not occur in practice (REWARD_NONE
 *   is only assigned to 0xdeadbeef entries created by action=0), but if it
 *   does → treat as incorrect → Type II
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::train_from_reward(TMPrefetchTrackerEntry* entry) {
    m_stats.learn.called++;

    int32_t reward = entry->reward;
    uint32_t action = entry->action_index;
    int32_t reward_type = entry->reward_type;

    // Special case: REWARD_NONE means the no-prefetch (action=0) PT entry
    // aged out without a demand access hitting the would-be-prefetched
    // location.  This is "correct restraint" — give Type I feedback so the
    // TM learns when conservatism is appropriate.
    if (reward_type == REWARD_NONE && action == 0) {
        m_tm->update(entry->features, action, true);
        m_stats.learn.learned_positive++;
        m_stats.reward.reward_per_action[reward_type][action]++;
        return;
    }

    if (reward > 0) {
        // Positive reward: reinforce the chosen action
        m_tm->update(entry->features, action, true);
        m_stats.learn.learned_positive++;
    } else if (reward < 0) {
        // Negative reward: penalize the chosen action
        m_tm->update(entry->features, action, false);
        m_stats.learn.learned_negative++;
    } else {
        m_stats.learn.learn_skipped_no_reward++;
    }

    // Track per-action reward distribution
    if (reward_type >= 0 && reward_type < NUM_REWARD_TYPES) {
        m_stats.reward.reward_per_action[reward_type][action]++;
    }
}

/* -------------------------------------------------------------------------
 * Bandwidth/IPC update callbacks (for system-aware operation)
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::update_bw(uint8_t bw_level) {
    m_bw_level = bw_level;
}

void TsetlinPrefetcher::update_ipc(uint8_t ipc) {
    // Reserved for future IPC-aware tuning
    (void)ipc;
}

void TsetlinPrefetcher::update_acc(uint32_t acc_level) {
    // Reserved for future cache-accuracy-aware tuning
    (void)acc_level;
}

bool TsetlinPrefetcher::is_high_bw() const {
    return m_bw_level >= m_high_bw_thresh;
}

/* -------------------------------------------------------------------------
 * Dynamic prefetch degree based on TM vote margin (P1.1: margin-based).
 *
 * Uses the vote MARGIN (class_sum[best] - class_sum[second_best]) as a
 * confidence proxy, rather than the absolute class sum.  This captures the
 * TM's certainty about which action is correct: a best=7 with second=6
 * (margin=1) is much less certain than best=7 with second=0 (margin=7),
 * even though both have the same absolute class sum.
 *
 * Margin range: [0, 2T] = [0, 16] for default T=8.
 * Thresholds should be scaled accordingly (~2× the old absolute values).
 *
 * Falls back to degree=1 if the action class sum is unavailable.
 * ------------------------------------------------------------------------- */
uint32_t TsetlinPrefetcher::get_dyn_pref_degree(uint32_t action_index)
{
    if (!m_enable_dyn_degree) {
        return m_pref_degree;
    }

    // action 0 = "no prefetch" → degree expansion is meaningless.
    if (action_index < m_max_actions && m_actions[action_index] == 0) {
        return 1;
    }

    // P1.1: margin-based confidence = best_class_sum - second_best_class_sum
    // Higher margin → clearer winner → more confidence → higher degree.
    int32_t best_sum   = m_tm->get_class_sum(action_index);
    int32_t second_sum = m_tm->get_second_best_class_sum();
    int32_t conf = best_sum - second_sum;
    if (conf < 0) conf = 0;  // clamp: shouldn't happen, but defensive

    const vector<int32_t>& thresholds = is_high_bw()
        ? m_dyn_deg_thresh_hbw : m_dyn_deg_thresh;
    const vector<int32_t>& degrees = is_high_bw()
        ? m_dyn_deg_values_hbw : m_dyn_deg_values;

    if (thresholds.empty() || degrees.empty()) {
        return 1;  // no thresholds configured → conservative
    }

    for (size_t i = 0; i < thresholds.size() && i < degrees.size(); i++) {
        if (conf <= thresholds[i]) {
            return (uint32_t)degrees[i];
        }
    }

    // Confidence exceeds all thresholds → use the highest degree
    return (uint32_t)degrees.back();
}

/* -------------------------------------------------------------------------
 * Generate additional prefetch addresses for multi-degree prefetching.
 *
 * Given a base page, offset, and action delta, issues extra prefetches at
 *   page + (offset + degree * action_delta) * BLOCK_SIZE
 * for degree = 2, 3, ..., pref_degree.
 *
 * All generated addresses must stay within the current page.
 * Extra prefetches are speculative (not PT-tracked) — only the base
 * degree-1 prefetch is tracked for reward feedback (same as Pythia).
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::gen_multi_degree_pref(
        uint64_t page, uint32_t offset,
        int32_t action_delta, uint32_t degree,
        vector<uint64_t>& pref_addr)
{
    m_stats.predict.multi_deg_called++;

    if (action_delta == 0 || degree <= 1) {
        return;
    }

    int32_t max_offset = (1 << (LOG2_PAGE_SIZE - LOG2_BLOCK_SIZE)) - 1;

    for (uint32_t d = 2; d <= degree; d++) {
        int32_t predicted_offset = (int32_t)offset + (int32_t)d * action_delta;
        if (predicted_offset >= 0 && predicted_offset <= max_offset) {
            uint64_t addr = (page << LOG2_PAGE_SIZE)
                          + ((uint64_t)predicted_offset << LOG2_BLOCK_SIZE);
            pref_addr.push_back(addr);
            m_stats.predict.multi_deg_issued++;
            m_stats.predict.multi_deg_histogram[d]++;
        }
    }
}

const char* TsetlinPrefetcher::get_reward_type_name(int32_t type) const {
    switch (type) {
        case REWARD_TIMELY:    return "timely";
        case REWARD_UNTIMELY:  return "untimely";
        case REWARD_INCORRECT: return "incorrect";
        case REWARD_NONE:      return "none";
        default:               return "unknown";
    }
}

/* -------------------------------------------------------------------------
 * print_config(): Output all configuration parameters
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::print_config() {
    cout << "=== Tsetlin Prefetcher Configuration ===" << endl;
    cout << "tsetlin_num_features " << m_num_features << endl;
    cout << "  - hash features       " << m_hash_feature_bits << " (PC, page)" << endl;
    cout << "  - offset thermometer  " << m_temp_offset_bits << " bits" << endl;
    cout << "  - delta thermometer   " << m_temp_delta_bits << " bits (+ 1 sign bit)" << endl;
    cout << "  - PCxPage interaction " << m_interaction_bits << " bits (P1.2)" << endl;
    cout << "  - BW thermometer      " << m_temp_bw_bits << " bits (P1.2)" << endl;
    cout << "  - Delta signature     " << m_delta_sig_bits << " bits (P1.3)" << endl;
    cout << "  - Access frequency    " << m_freq_bits << " bits (P1.4)" << endl;
    cout << "  - Confidence feedback " << m_conf_bits << " bits (P1.4)" << endl;
    cout << "tsetlin_num_actions " << m_max_actions << endl;
    cout << "tsetlin_actions ";
    for (size_t i = 0; i < m_actions.size(); i++) {
        cout << m_actions[i] << (i < m_actions.size()-1 ? "," : "");
    }
    cout << endl;
    cout << "tsetlin_last_offset_table " << LAST_OFFSET_TABLE_SIZE << " entries" << endl;
    cout << "tsetlin_pt_size " << m_pt_size << endl;
    cout << "tsetlin_pref_degree " << m_pref_degree << endl;
    cout << "tsetlin_enable_dyn_degree " << (m_enable_dyn_degree ? "true" : "false") << endl;
    cout << "tsetlin_dyn_deg_confidence_type margin-based (P1.1)" << endl;
    if (m_enable_dyn_degree) {
        cout << "tsetlin_dyn_deg_thresh (margin) ";
        for (size_t i = 0; i < m_dyn_deg_thresh.size(); i++)
            cout << m_dyn_deg_thresh[i] << (i < m_dyn_deg_thresh.size()-1 ? "," : "");
        cout << endl;
        cout << "tsetlin_dyn_deg_values ";
        for (size_t i = 0; i < m_dyn_deg_values.size(); i++)
            cout << m_dyn_deg_values[i] << (i < m_dyn_deg_values.size()-1 ? "," : "");
        cout << endl;
        cout << "tsetlin_dyn_deg_thresh_hbw (margin) ";
        for (size_t i = 0; i < m_dyn_deg_thresh_hbw.size(); i++)
            cout << m_dyn_deg_thresh_hbw[i] << (i < m_dyn_deg_thresh_hbw.size()-1 ? "," : "");
        cout << endl;
        cout << "tsetlin_dyn_deg_values_hbw ";
        for (size_t i = 0; i < m_dyn_deg_values_hbw.size(); i++)
            cout << m_dyn_deg_values_hbw[i] << (i < m_dyn_deg_values_hbw.size()-1 ? "," : "");
        cout << endl;
    }
    cout << "tsetlin_high_bw_thresh " << (int)m_high_bw_thresh << endl;
    cout << "tsetlin_epsilon_init " << m_epsilon_init
         << " (P2.2, current=" << m_explore.p() << ")" << endl;
    cout << "tsetlin_epsilon_min " << m_epsilon_min << endl;
    cout << "tsetlin_warmup_invocations " << m_warmup_invocations << endl;
    cout << endl;
}

/* -------------------------------------------------------------------------
 * dump_stats(): Output all statistics (ChampSim format)
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::dump_stats() {
    cout << "tsetlin_pt_lookup " << m_stats.pt.lookup << endl;
    cout << "tsetlin_pt_hit " << m_stats.pt.hit << endl;
    cout << "tsetlin_pt_evict " << m_stats.pt.evict << endl;
    cout << "tsetlin_pt_evict_filled " << m_stats.pt.evict_filled << endl;
    cout << "tsetlin_pt_evict_unfilled " << m_stats.pt.evict_unfilled << endl;
    cout << "tsetlin_pt_insert " << m_stats.pt.insert << endl;
    cout << endl;

    cout << "tsetlin_predict_called " << m_stats.predict.called << endl;
    cout << "tsetlin_predict_explore " << m_stats.predict.explore << endl;
    cout << "tsetlin_predict_exploit " << m_stats.predict.exploit << endl;
    cout << "tsetlin_predict_out_of_bounds " << m_stats.predict.out_of_bounds << endl;
    cout << "tsetlin_predict_predicted " << m_stats.predict.predicted << endl;
    cout << "tsetlin_predict_multi_deg_called " << m_stats.predict.multi_deg_called << endl;
    cout << "tsetlin_predict_multi_deg_issued " << m_stats.predict.multi_deg_issued << endl;

    for (uint32_t i = 0; i < m_max_actions; i++) {
        cout << "tsetlin_predict_action_" << m_actions[i] << " "
             << m_stats.predict.action_dist[i] << endl;
        cout << "tsetlin_predict_issue_action_" << m_actions[i] << " "
             << m_stats.predict.issue_dist[i] << endl;
    }
    for (size_t d = 1; d < m_stats.predict.deg_histogram.size(); d++) {
        cout << "tsetlin_degree_" << d << " " << m_stats.predict.deg_histogram[d] << endl;
    }
    for (size_t d = 2; d < m_stats.predict.multi_deg_histogram.size(); d++) {
        cout << "tsetlin_multi_deg_" << d << " " << m_stats.predict.multi_deg_histogram[d] << endl;
    }
    cout << endl;

    cout << "tsetlin_reward_called " << m_stats.reward.called << endl;
    cout << "tsetlin_reward_pt_not_found " << m_stats.reward.pt_not_found << endl;
    cout << "tsetlin_reward_pt_found " << m_stats.reward.pt_found << endl;
    cout << "tsetlin_reward_correct_timely " << m_stats.reward.correct_timely << endl;
    cout << "tsetlin_reward_correct_untimely " << m_stats.reward.correct_untimely << endl;
    cout << "tsetlin_reward_incorrect " << m_stats.reward.incorrect << endl;
    cout << "tsetlin_reward_no_pref " << m_stats.reward.no_pref << endl;
    cout << endl;

    for (uint32_t a = 0; a < m_max_actions; a++) {
        cout << "tsetlin_reward_" << m_actions[a] << " ";
        for (int r = 0; r < NUM_REWARD_TYPES; r++) {
            cout << m_stats.reward.reward_per_action[r][a] << ",";
        }
        cout << endl;
    }
    cout << endl;

    cout << "tsetlin_learn_called " << m_stats.learn.called << endl;
    cout << "tsetlin_learn_positive " << m_stats.learn.learned_positive << endl;
    cout << "tsetlin_learn_negative " << m_stats.learn.learned_negative << endl;
    cout << "tsetlin_learn_skipped " << m_stats.learn.learn_skipped_no_reward << endl;
    cout << endl;

    cout << "tsetlin_register_fill_called " << m_stats.register_fill.called << endl;
    cout << "tsetlin_register_fill_set " << m_stats.register_fill.set << endl;
    cout << endl;

    // TM internal state stats
    m_tm->dump_state();
}
