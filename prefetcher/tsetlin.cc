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
{
    // Clauses per action (evenly distributed)
    m_clauses_per_action = m_num_clauses / m_num_actions;
    assert(m_clauses_per_action >= 2 && "Need at least 2 clauses per action");

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
    // Pick a random "other" action for pairwise learning
    uint32_t negative_action;
    {
        std::uniform_int_distribution<uint32_t> neg_dist(0, m_num_actions - 1);
        do {
            negative_action = neg_dist(m_rng);
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
        for (uint32_t j = m_action_clause_start[negative_action];
             j < m_action_clause_start[negative_action] + m_clauses_per_action; j++) {
            if (skip_feedback((float)m_class_sum[negative_action], -1)) continue;
            m_feedback_to_clauses[j] = (m_clause_info[j].polarity >= 0) ? -1 : 1;
        }
    } else {
        // Negative: target gets Type II, other gets Type I (learn to avoid target)
        for (uint32_t j = m_action_clause_start[target_action];
             j < m_action_clause_start[target_action] + m_clauses_per_action; j++) {
            if (skip_feedback((float)m_class_sum[target_action], -1)) continue;
            m_feedback_to_clauses[j] = (m_clause_info[j].polarity >= 0) ? -1 : 1;
        }
        for (uint32_t j = m_action_clause_start[negative_action];
             j < m_action_clause_start[negative_action] + m_clauses_per_action; j++) {
            if (skip_feedback((float)m_class_sum[negative_action], 1)) continue;
            m_feedback_to_clauses[j] = (m_clause_info[j].polarity >= 0) ? 1 : -1;
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
        uint64_t seed, string type)
    : Prefetcher(type)
    , m_num_features(tm_cfg.num_features)
    , m_actions(actions)
    , m_max_actions((uint32_t)actions.size())
    , m_pt_size(pt_size)
    , m_bw_level(0)
    , m_high_bw_thresh(high_bw_thresh)
    , m_pref_degree(pref_degree)
    , m_enable_dyn_degree(false)
    , m_rng(seed)
    , m_explore(epsilon)
    , m_action_gen(0, m_max_actions - 1)
{
    // Create the Tsetlin Machine
    m_tm = new TsetlinMachine(tm_cfg);

    // Initialize last-offset tracking table
    for (uint32_t i = 0; i < LAST_OFFSET_TABLE_SIZE; i++) {
        m_last_offset_table[i].valid = false;
        m_last_offset_table[i].page_tag = 0;
        m_last_offset_table[i].last_offset = -1;
    }

    // Compute temperature encoding bit allocation (hybrid scheme)
    // Ordinal features (offset, delta) → temperature encoded (preserves ordering)
    // Categorical features (PC, page, bw_level) → hash encoded
    // Assumption: m_num_features >= 17 (8 offset + 8 delta + 1 sign)
    m_temp_offset_bits = 8;
    m_temp_delta_bits  = 8;
    m_hash_feature_bits = m_num_features - m_temp_offset_bits - m_temp_delta_bits - 1;
    assert(m_hash_feature_bits > 0 && "Need at least 17 features for hybrid encoding");

    // Initialize stats (zero-init scalars; vectors resized below)
    m_stats.pt.lookup = 0; m_stats.pt.hit = 0; m_stats.pt.evict = 0; m_stats.pt.insert = 0;
    m_stats.predict.called = 0; m_stats.predict.explore = 0; m_stats.predict.exploit = 0;
    m_stats.predict.out_of_bounds = 0; m_stats.predict.predicted = 0;
    m_stats.reward.called = 0; m_stats.reward.pt_not_found = 0; m_stats.reward.pt_found = 0;
    m_stats.reward.correct_timely = 0; m_stats.reward.correct_untimely = 0;
    m_stats.reward.incorrect = 0; m_stats.reward.no_pref = 0;
    m_stats.learn.called = 0; m_stats.learn.learned_positive = 0;
    m_stats.learn.learned_negative = 0; m_stats.learn.learn_skipped_no_reward = 0;
    m_stats.register_fill.called = 0; m_stats.register_fill.set = 0;

    m_stats.predict.action_dist.resize(m_max_actions, 0);
    m_stats.predict.issue_dist.resize(m_max_actions, 0);
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
 * Feature Generation: Program state → Binary feature vector
 *
 * HYBRID ENCODING SCHEME:
 * - Categorical features (PC, page, bw_level) → XOR-based hashing
 *   These are discrete IDs; hash encoding is appropriate since there is no
 *   meaningful ordering — PC 0x400100 and PC 0x400200 are different
 *   programs, not "larger/smaller" values.
 * - Ordinal features (offset, delta) → thermometer (temperature) encoding
 *   These are continuous/numeric with meaningful ordering. Thermometer
 *   encoding preserves monotonicity, allowing the TM to learn interval
 *   rules like "offset >= 32" via simple AND clauses.
 *
 * Feature layout (48 bits total with default config):
 *   [0..hash_bits-1]                    : hash(PC, page, bw_level)
 *   [hash_bits..hash_bits+7]            : thermometer(offset, 8 bits)
 *   [hash_bits+8..hash_bits+15]         : thermometer(|delta|, 8 bits)
 *   [hash_bits+16]                      : delta sign (1 = positive/zero)
 *
 * All operations are integer bitwise or comparisons → hardware-friendly.
 *
 * Inputs: PC, page, offset (block offset within page), delta (last stride),
 *         bw_level (DRAM bandwidth utilization level)
 * Output: binary features[0..num_features-1]
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::generate_features(
        uint64_t pc, uint64_t page, uint32_t offset,
        int32_t delta, uint8_t bw_level, int32_t* features)
{
    // ---- Part 1: Hash encoding for categorical features ----
    // PC and page are discrete IDs; bw_level is a coarse bucket (4 levels).
    uint64_t base = pc;
    base ^= (page << 3);
    base ^= ((uint64_t)bw_level << 21);

    for (uint32_t i = 0; i < m_hash_feature_bits; i++) {
        uint64_t h = base ^ ((uint64_t)i * 0x9E3779B97F4A7C15ULL);

        // splitmix64 mixing (all integer ops)
        h = (h ^ (h >> 30)) * 0xBF58476D1CE4E5B9ULL;
        h = (h ^ (h >> 27)) * 0x94D049BB133111EBULL;
        h = h ^ (h >> 31);

        features[i] = (int32_t)(h & 1);
    }

    // ---- Part 2: Thermometer encoding for block offset [0, 63] ----
    // threshold_i = i * 63 / 8 for i = 1..8
    // offset=0  → 00000000, offset=63 → 11111111 (monotonic)
    // All-integer comparison — a single parallel comparator array in HW.
    uint32_t feat_base = m_hash_feature_bits;
    for (uint32_t i = 0; i < m_temp_offset_bits; i++) {
        int32_t threshold = (int32_t)((i + 1) * 63 / m_temp_offset_bits);
        features[feat_base + i] = ((int32_t)offset >= threshold) ? 1 : 0;
    }

    // ---- Part 3: Thermometer encoding for delta magnitude [0, 63] ----
    // Delta range is naturally [-63, +63] for a 64-block page.
    // NOTE: the & 0xFFF mask in the old hash scheme is safe because 63
    //       fits in 6 bits, well within 12. If cross-page prefetching is
    //       added later, expand the magnitude encoding accordingly.
    uint32_t delta_mag = (uint32_t)((delta < 0) ? (-delta) : delta);
    feat_base += m_temp_offset_bits;
    for (uint32_t i = 0; i < m_temp_delta_bits; i++) {
        int32_t threshold = (int32_t)((i + 1) * 63 / m_temp_delta_bits);
        features[feat_base + i] = ((int32_t)delta_mag >= threshold) ? 1 : 0;
    }

    // ---- Part 4: Delta sign bit ----
    // 1 = forward/non-negative stride, 0 = backward stride
    feat_base += m_temp_delta_bits;
    features[feat_base] = (delta >= 0) ? 1 : 0;
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
    uint32_t lot_idx = (uint32_t)(page & (LAST_OFFSET_TABLE_SIZE - 1));
    LastOffsetEntry& lot_entry = m_last_offset_table[lot_idx];

    int32_t delta = 0;
    if (lot_entry.valid && lot_entry.page_tag == page) {
        // Hit: same page as last access → compute true stride
        delta = (int32_t)offset - lot_entry.last_offset;
    }
    // Always update the table for next access (within-page stride tracking)
    lot_entry.page_tag = page;
    lot_entry.last_offset = (int32_t)offset;
    lot_entry.valid = true;

    // ---- Step 3: Generate features ----
    int32_t* features = new int32_t[m_num_features];
    generate_features(pc, page, offset, delta, m_bw_level, features);

    // ---- Step 4: Predict action ----
    m_stats.predict.called++;

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
            }
        } else {
            m_stats.predict.out_of_bounds++;
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

    delete[] features;
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
    vector<TMPrefetchTrackerEntry*> result;
    for (auto* entry : m_pt) {
        if (entry->address == address && !entry->has_reward) {
            result.push_back(entry);
        }
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
        // High BW: wrong prefetches waste scarce BW → penalize harder
        case REWARD_INCORRECT: return high_bw ? -16 : -8;
        // High BW: no-prefetch decision that aged out → small penalty
        // (being conservative is less harmful when BW is tight)
        case REWARD_NONE:      return high_bw ? -2  : -4;
        default:               return 0;
    }
}

/* -------------------------------------------------------------------------
 * Train TM from a PT entry's reward
 *
 * Reward mapping to TM training:
 * - Timely/Untimely (>0): positive feedback → Type I for chosen action
 * - Incorrect (<0): negative feedback → Type II for chosen action
 * - None (action=0): treat as correct decision → Type I for action 0
 * - None (action!=0): treat as incorrect → Type II for chosen action
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::train_from_reward(TMPrefetchTrackerEntry* entry) {
    m_stats.learn.called++;

    int32_t reward = entry->reward;
    uint32_t action = entry->action_index;

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
    if (entry->reward_type >= 0 && entry->reward_type < NUM_REWARD_TYPES) {
        m_stats.reward.reward_per_action[entry->reward_type][action]++;
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
    cout << "  - hash features    " << m_hash_feature_bits << " (PC, page, bw_level)" << endl;
    cout << "  - offset thermometer " << m_temp_offset_bits << " bits" << endl;
    cout << "  - delta thermometer  " << m_temp_delta_bits << " bits (+ 1 sign bit)" << endl;
    cout << "tsetlin_num_actions " << m_max_actions << endl;
    cout << "tsetlin_actions ";
    for (size_t i = 0; i < m_actions.size(); i++) {
        cout << m_actions[i] << (i < m_actions.size()-1 ? "," : "");
    }
    cout << endl;
    cout << "tsetlin_last_offset_table " << LAST_OFFSET_TABLE_SIZE << " entries" << endl;
    cout << "tsetlin_pt_size " << m_pt_size << endl;
    cout << "tsetlin_pref_degree " << m_pref_degree << endl;
    cout << "tsetlin_high_bw_thresh " << (int)m_high_bw_thresh << endl;
    cout << "tsetlin_explore_eps " << m_explore.p() << endl;
    cout << endl;
}

/* -------------------------------------------------------------------------
 * dump_stats(): Output all statistics (ChampSim format)
 * ------------------------------------------------------------------------- */
void TsetlinPrefetcher::dump_stats() {
    cout << "tsetlin_pt_lookup " << m_stats.pt.lookup << endl;
    cout << "tsetlin_pt_hit " << m_stats.pt.hit << endl;
    cout << "tsetlin_pt_evict " << m_stats.pt.evict << endl;
    cout << "tsetlin_pt_insert " << m_stats.pt.insert << endl;
    cout << endl;

    cout << "tsetlin_predict_called " << m_stats.predict.called << endl;
    cout << "tsetlin_predict_explore " << m_stats.predict.explore << endl;
    cout << "tsetlin_predict_exploit " << m_stats.predict.exploit << endl;
    cout << "tsetlin_predict_out_of_bounds " << m_stats.predict.out_of_bounds << endl;
    cout << "tsetlin_predict_predicted " << m_stats.predict.predicted << endl;

    for (uint32_t i = 0; i < m_max_actions; i++) {
        cout << "tsetlin_predict_action_" << m_actions[i] << " "
             << m_stats.predict.action_dist[i] << endl;
        cout << "tsetlin_predict_issue_action_" << m_actions[i] << " "
             << m_stats.predict.issue_dist[i] << endl;
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
