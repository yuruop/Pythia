/*
 * Contextual Bandit (LinUCB) Prefetcher Implementation
 *
 * Implements a hardware-friendly LinUCB contextual bandit for data prefetching.
 * Core algorithm based on: Li et al., WWW 2010.
 *
 * Hardware-friendliness analysis:
 * - predict():  O(d²·|A|) dot products → ~100-200 MACs for d=8, |A|=15
 *   All ops are multiply-accumulate → pipeline-friendly, nanosecond-scale
 * - update():   Sherman-Morrison rank-1 update: O(d²) per action
 *   Outer-product + scalar multiply → fixed-point compatible
 * - Storage:    ~5 KB total (A_inv matrices + theta/b vectors + PT)
 * - All operations are dot products and matrix updates → no complex math
 */

#include <iostream>
#include <iomanip>
#include <cassert>
#include <cmath>
#include "linucb.h"

using namespace std;

// Maximum supported feature dimensionality.
// Must be >= m_num_features. Used for stack-allocated buffers on the hot path
// to avoid heap allocation on every demand request.
static constexpr uint32_t MAX_FEATURES = 32;  // P1.4: headroom for freq/conf

// Maximum block offset within a page, derived from system constants.
// Used for feature normalization — must match the bounds check in invoke_prefetcher().
static constexpr float kMaxOffsetFloat =
    (float)((1 << (LOG2_PAGE_SIZE - LOG2_BLOCK_SIZE)) - 1);

/* =========================================================================
 * LinUCB Implementation
 * ========================================================================= */

LinUCB::LinUCB(const Config& cfg)
    : m_num_actions(cfg.num_actions)
    , m_num_features(cfg.num_features)
    , m_alpha(cfg.alpha)
    , m_lambda(cfg.lambda_)
{
    // get_ucb_bonus() uses a stack-allocated working buffer of MAX_FEATURES floats.
    // Runtime check (not assert) — in Release/NDEBUG builds, assert is removed
    // and get_ucb_bonus() would silently overflow its stack buffer.
    if (m_num_features > MAX_FEATURES) {
        cerr << "FATAL: num_features " << m_num_features
             << " exceeds get_ucb_bonus() stack buffer limit of "
             << MAX_FEATURES << endl;
        abort();
    }

    size_t d = m_num_features;
    size_t d2 = d * d;
    size_t total_mat = m_num_actions * d2;
    size_t total_vec = m_num_actions * d;

    // Allocate per-action parameters
    m_A_inv = new float[total_mat];
    m_b     = new float[total_vec];
    m_theta = new float[total_vec];

    // Initialize: A_inv_i = (1/lambda) * I, b_i = 0, theta_i = 0
    for (size_t i = 0; i < m_num_actions; i++) {
        float* A_inv_i = m_A_inv + i * d2;
        float* b_i     = m_b     + i * d;
        float* theta_i = m_theta + i * d;

        // A_inv = (1/lambda) * I (identity scaled by 1/lambda)
        for (size_t r = 0; r < d; r++) {
            for (size_t c = 0; c < d; c++) {
                A_inv_i[r * d + c] = (r == c) ? (1.0f / m_lambda) : 0.0f;
            }
        }

        // b = 0, theta = 0
        for (size_t j = 0; j < d; j++) {
            b_i[j] = 0.0f;
            theta_i[j] = 0.0f;
        }
    }

    // Allocate working buffers
    m_Ax    = new float[d];
}

LinUCB::~LinUCB() {
    delete[] m_A_inv;
    delete[] m_b;
    delete[] m_theta;
    delete[] m_Ax;
}

/* -------------------------------------------------------------------------
 * Vector dot product
 * ------------------------------------------------------------------------- */
inline float LinUCB::dot(const float* a, const float* b) const {
    float sum = 0.0f;
    for (uint32_t i = 0; i < m_num_features; i++) {
        sum += a[i] * b[i];
    }
    return sum;
}

/* -------------------------------------------------------------------------
 * Matrix-vector multiply: out = mat * vec
 * mat is row-major d×d, vec is d×1
 * ------------------------------------------------------------------------- */
void LinUCB::mat_vec_mul(const float* mat, const float* vec, float* out) const {
    uint32_t d = m_num_features;
    for (uint32_t r = 0; r < d; r++) {
        float sum = 0.0f;
        for (uint32_t c = 0; c < d; c++) {
            sum += mat[r * d + c] * vec[c];
        }
        out[r] = sum;
    }
}

/* -------------------------------------------------------------------------
 * Rank-1 outer product subtraction: mat -= scale * (a ⊗ b)
 * mat[i*d + j] -= scale * a[i] * b[j]
 * ------------------------------------------------------------------------- */
void LinUCB::outer_product_sub(float* mat, const float* a, const float* b, float scale) {
    uint32_t d = m_num_features;
    for (uint32_t i = 0; i < d; i++) {
        for (uint32_t j = 0; j < d; j++) {
            mat[i * d + j] -= scale * a[i] * b[j];
        }
    }
}

/* -------------------------------------------------------------------------
 * predict(): compute UCB score for each action and return argmax
 *
 * score_i = theta_i^T * x + alpha * sqrt(x^T * A_inv_i * x)
 *
 * The first term is the expected reward (exploitation).
 * The second term is the confidence bound (exploration).
 * ------------------------------------------------------------------------- */
uint32_t LinUCB::predict(const float* features) {
    uint32_t d = m_num_features;
    float best_score = -1e30f;
    uint32_t best_action = 0;

    for (uint32_t i = 0; i < m_num_actions; i++) {
        const float* theta_i = m_theta + i * d;
        const float* A_inv_i = m_A_inv + i * d * d;

        // Expected reward: theta_i^T * x
        float expected = dot(theta_i, features);

        // Confidence bound: sqrt(x^T * A_inv_i * x)
        // First compute A_inv_i * x → m_Ax, then x^T * m_Ax
        mat_vec_mul(A_inv_i, features, m_Ax);
        float xAx = dot(features, m_Ax);
        float conf_bound = m_alpha * sqrtf(fmaxf(xAx, 0.0f));

        float score = expected + conf_bound;

        // Strict ">" (not ">=") means ties go to the lowest-index action.
        // In cold start (all theta=0, all A_inv identical), this systematically
        // favours action 0. The ε-greedy wrapper in ContextualBanditPrefetcher
        // mitigates this by injecting random exploration. Ties become rare once
        // any training has occurred because different actions receive different
        // updates and their UCB bonuses diverge.
        if (score > best_score) {
            best_score = score;
            best_action = i;
        }
    }

    return best_action;
}

/* -------------------------------------------------------------------------
 * predict_with_scores(): Full-score predict for feature-wise pooling and gating.
 *
 * Fills out_scores[i] with the UCB score for each action, and returns
 * best_score and avg_score (average over non-zero-delta actions) for
 * suppression gating.
 *
 * Returns: best action index.
 * ------------------------------------------------------------------------- */
uint32_t LinUCB::predict_with_scores(const float* features, float* out_scores,
                                      float* out_best_score, float* out_avg_score)
{
    uint32_t d = m_num_features;
    float best_score = -1e30f;
    uint32_t best_action = 0;
    float sum_scores = 0.0f;

    for (uint32_t i = 0; i < m_num_actions; i++) {
        const float* theta_i = m_theta + i * d;
        const float* A_inv_i = m_A_inv + i * d * d;

        float expected = dot(theta_i, features);
        mat_vec_mul(A_inv_i, features, m_Ax);
        float xAx = dot(features, m_Ax);
        float conf_bound = m_alpha * sqrtf(fmaxf(xAx, 0.0f));

        float score = expected + conf_bound;
        out_scores[i] = score;
        sum_scores += score;

        if (score > best_score) {
            best_score = score;
            best_action = i;
        }
    }

    if (out_best_score) *out_best_score = best_score;
    if (out_avg_score) {
        *out_avg_score = (m_num_actions > 0) ? (sum_scores / (float)m_num_actions) : 0.0f;
    }

    return best_action;
}

/* -------------------------------------------------------------------------
 * update(): Sherman-Morrison incremental update
 *
 * A_inv = A_inv - (A_inv * x * x^T * A_inv) / (1 + x^T * A_inv * x)
 * b = b + reward * x
 * theta = A_inv * b
 *
 * This is O(d²) per update — very efficient for small d.
 * ------------------------------------------------------------------------- */
void LinUCB::update(const float* features, uint32_t action, float reward) {
    // NOTE: Sherman-Morrison is an INCREMENTAL update operating in float32.
    // Over very long runs (billions of accesses), the A_inv matrix may gradually
    // lose positive-definiteness or symmetry due to accumulated round-off error.
    // This is a known limitation of incremental inverse-covariance methods.
    // Mitigations in place:
    //   - fmaxf(xAx, 0.0f) guards against negative (numerically impossible) values
    //   - theta is recomputed from A_inv * b each update (not incrementally),
    //     preventing error propagation in the weight vector
    // For production hardware, consider periodic full recomputation of A_inv
    // from stored raw feature outer products, or use double precision for A_inv.
    uint32_t d = m_num_features;
    float* A_inv_i = m_A_inv + action * d * d;
    float* b_i     = m_b     + action * d;
    float* theta_i = m_theta + action * d;

    // ---- Sherman-Morrison update for A_inv ----
    // Step 1: A_inv * x → m_Ax
    mat_vec_mul(A_inv_i, features, m_Ax);

    // Step 2: x^T * A_inv * x = x^T * m_Ax
    float xAx = dot(features, m_Ax);

    // Step 3: factor = 1 / (1 + x^T * A_inv * x)
    // Avoid division by zero; xAx >= 0 always in theory for PD matrix
    float factor = 1.0f / (1.0f + fmaxf(xAx, 0.0f));

    // Step 4: A_inv -= factor * (m_Ax ⊗ m_Ax)
    // Note: since A_inv is symmetric and m_Ax ⊗ m_Ax is symmetric,
    // we only need to update the upper triangle. But for simplicity
    // and small d, we update the full matrix.
    outer_product_sub(A_inv_i, m_Ax, m_Ax, factor);

    // ---- Update b and theta ----
    // b = b + reward * x
    for (uint32_t j = 0; j < d; j++) {
        b_i[j] += reward * features[j];
    }

    // theta = A_inv * b (recompute after update)
    mat_vec_mul(A_inv_i, b_i, theta_i);
}

float LinUCB::get_theta(uint32_t action, uint32_t feat) const {
    return m_theta[action * m_num_features + feat];
}

/* -------------------------------------------------------------------------
 * Expected reward (exploitation term only, no UCB bonus).
 * Used as a confidence proxy for dynamic degree selection.
 * ------------------------------------------------------------------------- */
float LinUCB::get_expected_reward(const float* features, uint32_t action) const {
    const float* theta_i = m_theta + action * m_num_features;
    return dot(theta_i, features);
}

float LinUCB::get_ucb_bonus(const float* features, uint32_t action) const {
    uint32_t d = m_num_features;
    const float* A_inv_i = m_A_inv + action * d * d;

    // Use stack-local working buffer (d ≤ MAX_FEATURES → up to 128 bytes)
    // Avoids const_cast and keeps this method truly const / thread-safe
    float work[MAX_FEATURES];  // P1.4: expanded from 8 to MAX_FEATURES for freq/conf features
    for (uint32_t r = 0; r < d; r++) {
        float sum = 0.0f;
        for (uint32_t c = 0; c < d; c++) {
            sum += A_inv_i[r * d + c] * features[c];
        }
        work[r] = sum;
    }

    float xAx = 0.0f;
    for (uint32_t i = 0; i < d; i++) {
        xAx += features[i] * work[i];
    }

    return m_alpha * sqrtf(fmaxf(xAx, 0.0f));
}

void LinUCB::dump_state() const {
    cout << "=== LinUCB State ===" << endl;
    cout << "actions=" << m_num_actions << " features=" << m_num_features
         << " alpha=" << m_alpha << " lambda=" << m_lambda << endl;

    // Compute average ||theta|| as a convergence indicator
    float avg_norm = 0.0f;
    for (uint32_t i = 0; i < m_num_actions; i++) {
        const float* theta_i = m_theta + i * m_num_features;
        float norm2 = 0.0f;
        for (uint32_t j = 0; j < m_num_features; j++) {
            norm2 += theta_i[j] * theta_i[j];
        }
        avg_norm += sqrtf(norm2);
    }
    avg_norm /= m_num_actions;
    cout << "avg_theta_norm=" << fixed << setprecision(4) << avg_norm << endl;

    // Average diagonal of A_inv (confidence indicator)
    float avg_diag = 0.0f;
    for (uint32_t i = 0; i < m_num_actions; i++) {
        const float* A_inv_i = m_A_inv + i * m_num_features * m_num_features;
        for (uint32_t j = 0; j < m_num_features; j++) {
            avg_diag += A_inv_i[j * m_num_features + j];
        }
    }
    avg_diag /= (m_num_actions * m_num_features);
    cout << "avg_A_inv_diag=" << fixed << setprecision(6) << avg_diag
         << " (init=" << (1.0f / m_lambda) << ", lower=more confidence)"
         << endl;
}


/* =========================================================================
 * ContextualBanditPrefetcher Implementation
 * ========================================================================= */

ContextualBanditPrefetcher::ContextualBanditPrefetcher(
        const LinUCB::Config& cb_cfg,
        const vector<int32_t>& actions,
        uint32_t pt_size, uint32_t pref_degree,
        float epsilon, uint8_t high_bw_thresh,
        uint64_t seed, string type,
        bool enable_dyn_degree,
        const vector<int32_t>& dyn_deg_thresh,
        const vector<int32_t>& dyn_deg_values,
        const vector<int32_t>& dyn_deg_thresh_hbw,
        const vector<int32_t>& dyn_deg_values_hbw,
        bool featurewise,
        int32_t lcb_pooling_mode,
        float lcb_weight_lr,
        bool suppress_gating,
        float suppress_ratio,
        bool history_features)
    : Prefetcher(type)
    , m_num_features(cb_cfg.num_features)
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
    , m_epsilon(epsilon)
    , m_rng(seed)
    , m_explore(epsilon)
    , m_action_gen(0, m_max_actions - 1)
    , m_dist(0.0f, 1.0f)
    , m_reward_head(0)
    , m_reward_sum(0.0f)
    , m_reward_count(0.0f)
    , m_positive_sum(0.0f)         // P1.6
    , m_no_pref_action_idx(0)
    , m_featurewise(featurewise)
    , m_feature_models(nullptr)
    , m_num_feature_models(0)
    , m_lcb_pooling((LcbPoolingMode)lcb_pooling_mode)
    , m_lcb_weight_lr(lcb_weight_lr)
    , m_lcb_weight_reg(1.0f)
    , m_cached_best_score(0.0f)
    , m_cached_avg_score(0.0f)
    , m_last_confidence(0.0f)
    , m_suppress_gating(suppress_gating)
    , m_suppress_ratio(suppress_ratio)
    , m_history_features(history_features)
    , m_history_head(0)
    , m_history_count(0)
{
    // Initialize score cache
    for (uint32_t i = 0; i < 32; i++) m_cached_scores[i] = 0.0f;

    // Initialize history queues
    for (uint32_t i = 0; i < HISTORY_DEPTH; i++) {
        m_recent_pcs[i] = 0;
        m_recent_deltas[i] = 0;
    }

    // Initialize reward ring buffer
    for (uint32_t i = 0; i < REWARD_WINDOW; i++) {
        m_reward_ring[i] = 0.0f;
    }

    // Cache the index of action=0 for fast no-prefetch suppression
    for (uint32_t i = 0; i < m_max_actions; i++) {
        if (m_actions[i] == 0) { m_no_pref_action_idx = i; break; }
    }

    // Create the LinUCB engine(s)
    if (m_featurewise) {
        init_featurewise_models(cb_cfg);
        m_linucb = nullptr;  // monolithic model not used in feature-wise mode
    } else {
        m_linucb = new LinUCB(cb_cfg);
    }

    // P2.7: Validate history feature layout (L-CRIT-2 fix).
    // History features occupy the last 2 slots ([num_features-2] and
    // [num_features-1]).  To avoid silently overwriting stride_streak
    // (index 11) and delta_var_ema (index 12), we require at least 14
    // features when history is enabled:
    //   [0..10]  = 11 baseline features (PC, Page, Offset, Delta, ...)
    //   [11]     = stride_streak (P1.5, when num_features > 11)
    //   [12..13] = history features (h_idx = num_features-2 = 12)
    // If you also want delta variance EMA, use num_features >= 15:
    //   [12]     = delta_var_ema (P2.7, when num_features > 12)
    //   [13..14] = history features
    if (m_history_features && m_num_features < 14) {
        cerr << "FATAL: history_features requires num_features >= 13 "
             << "(got " << m_num_features << "). "
             << "Increase linucb_num_features by at least 2." << endl;
        abort();
    }

    // invoke_prefetcher() uses a stack-allocated features[MAX_FEATURES] buffer
    // on the hot path to avoid heap allocation. Runtime check (not assert) —
    // in Release/NDEBUG builds, this would silently stack-overflow.
    if (m_num_features > MAX_FEATURES) {
        cerr << "FATAL: num_features " << m_num_features
             << " exceeds invoke_prefetcher() stack buffer limit of "
             << MAX_FEATURES << endl;
        abort();
    }

    // Initialize last-offset tracking table
    for (uint32_t i = 0; i < LAST_OFFSET_TABLE_SIZE; i++) {
        m_last_offset_table[i].valid = false;
        m_last_offset_table[i].page_tag = 0;
        m_last_offset_table[i].last_offset = -1;
    }

    // Zero-init all statistics
    m_stats.pt.lookup = 0; m_stats.pt.hit = 0; m_stats.pt.evict = 0; m_stats.pt.insert = 0;
    m_stats.predict.called = 0; m_stats.predict.explore = 0; m_stats.predict.exploit = 0;
    m_stats.predict.out_of_bounds = 0; m_stats.predict.predicted = 0;
    m_stats.predict.multi_deg_called = 0; m_stats.predict.multi_deg_issued = 0;
    m_stats.predict.gating_checked = 0; m_stats.predict.gating_suppressed = 0;
    m_stats.reward.called = 0; m_stats.reward.pt_not_found = 0; m_stats.reward.pt_found = 0;
    m_stats.reward.correct_timely = 0; m_stats.reward.correct_untimely = 0;
    m_stats.reward.incorrect = 0; m_stats.reward.no_pref = 0;
    m_stats.learn.called = 0; m_stats.learn.learned_positive = 0;
    m_stats.learn.learned_negative = 0; m_stats.learn.learn_skipped_no_reward = 0;
    m_stats.suppress.called = 0; m_stats.suppress.suppressed = 0;        // P1.6
    m_stats.suppress.suppressed_prob = 0; m_stats.suppress.suppressed_escape = 0;  // P1.6
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

    // Feature-wise stats (P2.3)
    m_stats.featurewise.pooled_predicts = 0;
    m_stats.featurewise.weight_updates = 0;
    for (uint32_t i = 0; i < 8; i++) {
        m_stats.featurewise.model_agrees[i] = 0;
    }
}

ContextualBanditPrefetcher::~ContextualBanditPrefetcher() {
    if (m_featurewise) {
        if (m_feature_models) {
            for (uint32_t i = 0; i < m_num_feature_models; i++) {
                delete m_feature_models[i].model;
            }
            delete[] m_feature_models;
        }
    } else {
        delete m_linucb;
    }
    while (!m_pt.empty()) {
        delete m_pt.back();
        m_pt.pop_back();
    }
}

/* =========================================================================
 * P2.3: Feature-wise LinUCB — initialization, predict, train
 * ========================================================================= */

/* -------------------------------------------------------------------------
 * init_featurewise_models(): Create sub-LinUCB models per feature group.
 *
 * Natural decomposition of the 11-feature layout:
 *   Model 0 "PC"       : [0] PC hash
 *   Model 1 "Page"     : [1] Page hash
 *   Model 2 "Offset"   : [2] Block offset
 *   Model 3 "Delta"    : [3,4] Delta + Delta sign
 *   Model 4 "BW"       : [5] BW level
 *   Model 5 "Interaction": [6,7] PC×Page + Offset×Delta
 *   Model 6 "Context"  : [8,9,10] DeltaSig + Freq + Confidence
 *   Model 7 "History"  : [m_num_features-2, m_num_features-1] (if enabled)
 *
 * Each model has its own A_inv, theta, b — total storage is SIMILAR to the
 * monolithic model because sum(d_i^2) < D^2 for any decomposition of D features.
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::init_featurewise_models(const LinUCB::Config& base_cfg)
{
    // Define feature groups as {start, count} pairs
    struct { uint32_t start; uint32_t count; } groups[8];
    uint32_t g = 0;

    // Model 0: PC hash (feature index 0)
    groups[g++] = {0, 1};

    // Model 1: Page hash (feature index 1)
    groups[g++] = {1, 1};

    // Model 2: Block offset (feature index 2)
    groups[g++] = {2, 1};

    // Model 3: Delta + Delta sign (feature indices 3,4)
    groups[g++] = {3, 2};

    // Model 4: BW level (feature index 5) — only if m_num_features > 5
    if (m_num_features > 5) {
        groups[g++] = {5, 1};
    }

    // Model 5: Interaction features (feature indices 6,7) — only if m_num_features > 7
    if (m_num_features > 7) {
        groups[g++] = {6, 2};
    }

    // Model 6: Context features (feature indices 8+) if present
    uint32_t context_start = 8;
    if (m_num_features > 8) {
        uint32_t context_count = m_num_features - 8;
        // History features occupy the last 2 slots, exclude them
        if (m_history_features && context_count > 2) {
            context_count -= 2;
        }
        groups[g++] = {context_start, context_count};
    }

    // Model 7: History features (last 2 slots) if enabled
    if (m_history_features && m_num_features >= 2) {
        groups[g++] = {m_num_features - 2, 2};
    }

    m_num_feature_models = g;
    m_feature_models = new LinUCBFeatureModel[g];

    for (uint32_t i = 0; i < g; i++) {
        LinUCB::Config cfg = base_cfg;
        cfg.num_features = groups[i].count;
        cfg.seed = base_cfg.seed + i * 137;  // different seed per model
        m_feature_models[i].model = new LinUCB(cfg);
        m_feature_models[i].feat_start = groups[i].start;
        m_feature_models[i].feat_count = groups[i].count;
        m_feature_models[i].weight = 1.0f / (float)g;
        m_feature_models[i].accuracy_ema = 0.5f;
    }
}

/* -------------------------------------------------------------------------
 * predict_featurewise(): Pool UCB scores from all sub-models.
 *
 * Each sub-model computes its own UCB scores.  The pooling layer aggregates:
 *   LCB_POOL_MAX:      pooled[a] = max_i(scores_i[a])
 *   LCB_POOL_WEIGHTED: pooled[a] = sum_i(weight[i] * scores_i[a])
 *
 * Returns argmax of pooled scores. Caches best/avg for suppression gating.
 * ------------------------------------------------------------------------- */
uint32_t ContextualBanditPrefetcher::predict_featurewise(const float* features)
{
    m_stats.featurewise.pooled_predicts++;

    // Collect per-model scores.
    // Each sub-model's predict_with_scores fills its own row in
    // model_scores_arr.  We only need the scores for pooling; the
    // per-model best_score/avg_score output params are not used here.
    float model_scores_arr[8][32];  // max 8 models, each up to 32 actions

    for (uint32_t m = 0; m < m_num_feature_models; m++) {
        m_feature_models[m].model->predict_with_scores(
            features + m_feature_models[m].feat_start,
            model_scores_arr[m], nullptr, nullptr);
    }

    // Pool scores across models
    uint32_t num_actions = m_max_actions;
    if (num_actions > 32) num_actions = 32;

    float best_pooled = -1e30f;
    uint32_t best_action = 0;
    float sum_pooled = 0.0f;

    for (uint32_t a = 0; a < num_actions; a++) {
        float pooled;
        if (m_lcb_pooling == LCB_POOL_MAX) {
            pooled = -1e30f;
            for (uint32_t m = 0; m < m_num_feature_models; m++) {
                if (model_scores_arr[m][a] > pooled) pooled = model_scores_arr[m][a];
            }
        } else {
            // LCB_POOL_WEIGHTED
            pooled = 0.0f;
            for (uint32_t m = 0; m < m_num_feature_models; m++) {
                pooled += m_feature_models[m].weight * model_scores_arr[m][a];
            }
        }
        m_cached_scores[a] = pooled;
        sum_pooled += pooled;

        if (pooled > best_pooled) {
            best_pooled = pooled;
            best_action = a;
        }
    }

    m_cached_best_score = best_pooled;
    m_cached_avg_score = (num_actions > 0) ? (sum_pooled / (float)num_actions) : 0.0f;

    // Track per-model agreement
    for (uint32_t m = 0; m < m_num_feature_models && m < 8; m++) {
        // Find this model's best action from its scores
        uint32_t m_best = 0;
        float m_best_score = model_scores_arr[m][0];
        for (uint32_t a = 1; a < num_actions; a++) {
            if (model_scores_arr[m][a] > m_best_score) {
                m_best_score = model_scores_arr[m][a];
                m_best = a;
            }
        }
        if (m_best == best_action) {
            m_stats.featurewise.model_agrees[m]++;
        }
    }

    return best_action;
}

/* -------------------------------------------------------------------------
 * train_featurewise(): Route update to all sub-models.
 *
 * Each sub-model receives the same scaled reward for the chosen action.
 * Weights are updated via EMA of correctness (same as Tsetlin).
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::train_featurewise(
        const float* features, uint32_t action, float scaled_reward)
{
    for (uint32_t m = 0; m < m_num_feature_models; m++) {
        m_feature_models[m].model->update(
            features + m_feature_models[m].feat_start, action, scaled_reward);
    }

    // Weight update for LCB_POOL_WEIGHTED mode
    if (m_lcb_pooling == LCB_POOL_WEIGHTED && m_lcb_weight_lr > 0.0f) {
        m_stats.featurewise.weight_updates++;
        float correct = (scaled_reward > 0.0f) ? 1.0f : 0.0f;
        float weight_sum = 0.0f;
        for (uint32_t m = 0; m < m_num_feature_models; m++) {
            m_feature_models[m].accuracy_ema =
                m_feature_models[m].accuracy_ema * (1.0f - m_lcb_weight_lr)
                + m_lcb_weight_lr * correct;
            // Softmax-like reweight: weight ∝ exp(accuracy_ema / temperature)
            float temp = 0.5f;
            m_feature_models[m].weight = expf(m_feature_models[m].accuracy_ema / temp);
            weight_sum += m_feature_models[m].weight;
        }
        // Renormalize
        if (weight_sum > 0.0f) {
            for (uint32_t m = 0; m < m_num_feature_models; m++) {
                m_feature_models[m].weight /= weight_sum;
            }
        }
    }
}

/* =========================================================================
 * P2.6: History / Path features
 * ========================================================================= */

/* -------------------------------------------------------------------------
 * generate_history_features(): Append 2 features from recent PC/delta queues.
 *
 * Feature [num_features-2]: hash of recent PCs → [0, 1]
 * Feature [num_features-1]: hash of recent deltas → [0, 1]
 *
 * The history features capture temporal context — what the program has been
 * doing recently.  This is one of Pythia's key predictive signals.
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::generate_history_features(float* features)
{
    if (!m_history_features || m_num_features < 2) return;

    uint32_t h_idx = m_num_features - 2;

    if (m_history_count > 0) {
        // Feature h_idx: hash of recent PCs
        uint64_t pc_hash = 0;
        for (uint32_t i = 0; i < m_history_count && i < HISTORY_DEPTH; i++) {
            uint32_t idx = (m_history_head + HISTORY_DEPTH - 1 - i) % HISTORY_DEPTH;
            pc_hash ^= m_recent_pcs[idx] + (uint64_t)i * 0x9E3779B97F4A7C15ULL;
        }
        features[h_idx] = hash_to_float(pc_hash, 42);

        // Feature h_idx+1: hash of recent deltas
        uint64_t delta_hash = 0;
        for (uint32_t i = 0; i < m_history_count && i < HISTORY_DEPTH; i++) {
            uint32_t idx = (m_history_head + HISTORY_DEPTH - 1 - i) % HISTORY_DEPTH;
            delta_hash ^= (uint64_t)(m_recent_deltas[idx] + 128)
                        * (uint64_t)(i + 1) * 0x9E3779B97F4A7C15ULL;
        }
        features[h_idx + 1] = hash_to_float(delta_hash, 137);
    } else {
        // Not enough history yet — neutral features
        features[h_idx] = 0.5f;
        features[h_idx + 1] = 0.5f;
    }
}

/* -------------------------------------------------------------------------
 * Hash a 64-bit value to a normalized float in [0, 1]
 *
 * Uses splitmix64 mixing for good distribution, then scales to [0,1].
 * All integer operations — hardware-friendly.
 * ------------------------------------------------------------------------- */
inline float ContextualBanditPrefetcher::hash_to_float(uint64_t value, uint32_t seed) const {
    uint64_t h = value ^ ((uint64_t)seed * 0x9E3779B97F4A7C15ULL);

    // splitmix64 mixing
    h = (h ^ (h >> 30)) * 0xBF58476D1CE4E5B9ULL;
    h = (h ^ (h >> 27)) * 0x94D049BB133111EBULL;
    h = h ^ (h >> 31);

    // Scale to [0, 1] using the upper 24 bits for mantissa precision
    // Equivalent to: (h & 0xFFFFFF) / 16777215.0
    return (float)(h & 0xFFFFFF) / 16777215.0f;
}

/* -------------------------------------------------------------------------
 * Feature Generation: Program state → Continuous feature vector (9-13 dims, P1.5)
 *
 * DESIGN RATIONALE:
 * Unlike the Tsetlin Machine which requires BINARY features, LinUCB naturally
 * handles REAL-VALUED features.  Optional features [9]-[12] are enabled
 * by increasing linucb_num_features in the .ini config.
 *
 * Feature layout (default 11, extendable via num_features):
 *   [0] PC hash                         → [0, 1]
 *   [1] Page hash                       → [0, 1]
 *   [2] Block offset (normalized)       → [0, 1]
 *   [3] Delta (normalized)              → [-1, 1]
 *   [4] Delta sign                      → {-1, 0, 1}
 *   [5] BW level (normalized)           → [0, 1]
 *   [6] PC×Page interaction hash        → [0, 1]
 *   [7] Offset/Delta interaction        → [-1, 1]
 *   [8] Delta signature (normalized)    → [0, 1]   (P1.3)
 *   [9] Access frequency (normalized)   → [0, 1]   (P1.4, if num_features>9)
 *   [10] Confidence feedback            → [0, 1]   (P1.4, if num_features>10)
 *   [11] Stride streak (normalized)     → [0, 1]   (P1.5, if num_features>11)
 *   [12] Delta variance EMA (norm.)     → [0, 1]   (P1.5, if num_features>12)
 *
 * Computes: O(d) simple operations per invocation
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::generate_features(
        uint64_t pc, uint64_t page, uint32_t offset,
        int32_t delta, uint8_t bw_level, uint32_t delta_sig,
        uint32_t access_count, float last_confidence,
        uint8_t stride_streak, float* features)
{
    // Feature 0: PC hash → [0, 1]
    features[0] = hash_to_float(pc, 0);

    // Feature 1: Page hash → [0, 1]
    features[1] = hash_to_float(page, 1);

    // Feature 2: Block offset → [0, 1]
    // kMaxOffsetFloat is derived from LOG2_PAGE_SIZE - LOG2_BLOCK_SIZE, keeping
    // normalization consistent with the bounds check in invoke_prefetcher().
    features[2] = (float)offset / kMaxOffsetFloat;

    // Feature 3: Delta → [-1, 1] (clamped to within-page strides)
    float delta_clamped = fmaxf(-kMaxOffsetFloat, fminf(kMaxOffsetFloat, (float)delta));
    features[3] = delta_clamped / kMaxOffsetFloat;

    // Feature 4: Delta sign → {-1, 1}
    features[4] = (delta > 0) ? 1.0f : ((delta < 0) ? -1.0f : 0.0f);

    // Feature 5: BW level → [0, 1]
    features[5] = (float)bw_level / (float)(DRAM_BW_LEVELS - 1);

    // Remaining features (if m_num_features > 6): interaction features
    if (m_num_features > 6) {
        // Feature 6: PC × Page interaction → [0, 1]
        features[6] = hash_to_float(pc ^ (page << 7), 2);
    }
    if (m_num_features > 7) {
        // Feature 7: Offset / Delta interaction → [-1, 1]
        // Captures the relationship between current position and stride
        float interaction = features[2] * features[3];
        features[7] = fmaxf(-1.0f, fminf(1.0f, interaction));
    }
    if (m_num_features > 8) {
        // Feature 8: Delta signature → [0, 1] (P1.3 NEW)
        // 12-bit shift-XOR hash of last 4 deltas (SPP-style encoding).
        // Normalized by DELTA_SIG_MASK (0xFFF) to [0, 1].
        features[8] = (float)(delta_sig & DELTA_SIG_MASK) / (float)DELTA_SIG_MASK;
    }
    if (m_num_features > 9) {
        // Feature 9: Access frequency → [0, 1] (P1.4 NEW)
        // Per-page saturating access count, normalized by 255.
        features[9] = (float)access_count / 255.0f;
    }
    if (m_num_features > 10) {
        // Feature 10: Confidence feedback → [0, 1] (P1.4 NEW)
        // |expected_reward| from the last prediction on this page.
        // Enables second-order reasoning for LinUCB as well.
        features[10] = last_confidence;  // already in [0, 1]
    }
    if (m_num_features > 11) {
        // Feature 11: Stride streak → [0, 1] (P1.5 NEW)
        // Consecutive accesses with the same delta.  High streak means a
        // stable, predictable stride — ideal for multi-degree prefetch.
        // Low streak means irregular access pattern → be conservative.
        // Normalized by max expected streak (16).
        features[11] = (float)stride_streak / 16.0f;
        if (features[11] > 1.0f) features[11] = 1.0f;
    }
    if (m_num_features > 12) {
        // Feature 12: Delta variance EMA → [0, 1] (P1.5 NEW)
        // Not computed here — the caller passes 0 when num_features <= 12.
        // When enabled, the LastOffsetEntry tracks an EMA of
        // |delta - prev_delta| / 64, providing a direct "chaos" signal.
        // Placeholder: set in invoke_prefetcher via a separate field.
        features[12] = 0.0f;
    }
    // Additional features (if m_num_features > 13): just pad with zeros
    for (uint32_t i = 13; i < m_num_features; i++) {
        features[i] = 0.0f;
    }

    // P2.6: History/path features (overwrites last 2 slots when enabled)
    if (m_history_features) {
        generate_history_features(features);
    }
}

/* -------------------------------------------------------------------------
 * invoke_prefetcher(): Main entry point, called on every demand request
 *
 * Flow:
 * 1. Compute reward for previously tracked prefetches
 * 2. Extract program state (page, offset, delta)
 * 3. Generate continuous features from state
 * 4. LinUCB predict → action index (with ε-greedy exploration)
 * 5. Issue prefetch or track no-prefetch decision
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::invoke_prefetcher(
        uint64_t pc, uint64_t address, uint8_t cache_hit,
        uint8_t type, vector<uint64_t>& pref_addr)
{
    uint64_t page   = address >> LOG2_PAGE_SIZE;
    uint32_t offset = (address >> LOG2_BLOCK_SIZE) &
                      ((1ull << (LOG2_PAGE_SIZE - LOG2_BLOCK_SIZE)) - 1);

    // ---- Step 1: Compute reward for previous prefetches ----
    {
        m_stats.reward.called++;
        vector<CBPrefetchTrackerEntry*> matches = search_pt(address);
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

                // Train LinUCB
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
    float    last_confidence = 0.0f;
    uint8_t  stride_streak = 0;       // P1.5

    if (lot_entry.valid && lot_entry.page_tag == page) {
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

        // P1.5: track stride streak (consecutive same-delta count)
        if (delta == lot_entry.last_delta) {
            if (lot_entry.stride_streak < 255) {
                lot_entry.stride_streak++;
            }
        } else {
            lot_entry.stride_streak = 1;
        }

        // P2.7: delta variance EMA (L-CRIT-1 fix).
        // EMA of |delta - prev_delta| / 64, normalized to [0,1].
        // Replaces the old placeholder (always 0.0f) with a real signal.
        // Low variance → stable, predictable stride → high confidence.
        // High variance → irregular access → low confidence.
        // EMA decay 7/8 keeps 87.5% of history, updates 12.5% from new sample.
        float delta_change = (float)((delta > lot_entry.last_delta)
            ? (delta - lot_entry.last_delta)
            : (lot_entry.last_delta - delta));
        float delta_change_norm = delta_change / 64.0f;
        if (delta_change_norm > 1.0f) delta_change_norm = 1.0f;
        lot_entry.delta_var_ema = lot_entry.delta_var_ema * 0.875f
                                + delta_change_norm * 0.125f;

        lot_entry.last_delta = delta;
    } else {
        // First access to this page or page collision: reset all
        // page-specific tracking fields to avoid leaking state from
        // the previous page that occupied this slot.
        lot_entry.access_count = 1;
        lot_entry.delta_sig = 0;
        lot_entry.last_confidence = 0.0f;
        lot_entry.stride_streak = 0;     // P1.5
        lot_entry.last_delta = delta;    // P1.5
        lot_entry.delta_var_ema = 0.0f; // P2.7: reset variance on new page
    }
    delta_sig = lot_entry.delta_sig;
    access_count = lot_entry.access_count;
    last_confidence = lot_entry.last_confidence;
    stride_streak = lot_entry.stride_streak;  // P1.5
    float delta_var_ema = lot_entry.delta_var_ema;  // P2.7

    lot_entry.page_tag = page;
    lot_entry.last_offset = (int32_t)offset;
    lot_entry.valid = true;

    // ---- P2.6: Update history queues ----
    if (m_history_features) {
        m_recent_pcs[m_history_head] = pc;
        m_recent_deltas[m_history_head] = delta;
        m_history_head = (m_history_head + 1) % HISTORY_DEPTH;
        if (m_history_count < HISTORY_DEPTH) m_history_count++;
    }

    // ---- Step 3: Generate features ----
    // Stack-allocated to avoid heap allocation on the hot path (every demand request).
    // MAX_FEATURES is a generous upper bound; m_num_features is asserted at construction.
    float features[MAX_FEATURES];
    generate_features(pc, page, offset, delta, m_bw_level, delta_sig,
                      access_count, last_confidence, stride_streak, features);

    // P2.7 (L-CRIT-1 fix): Delta variance EMA — replaces the old always-0.0f
    // placeholder with a real signal.  Feature 12 now reflects actual delta
    // stability, giving LinUCB a useful confidence-related signal.
    if (m_num_features > 12) {
        features[12] = delta_var_ema;
    }

    // ---- Step 4: Predict action ----
    m_stats.predict.called++;

    uint32_t action_index;
    bool is_exploit = false;  // P1.6(c): track for suppression bypass
    if (m_explore(m_rng)) {
        // ε-greedy exploration: random action.
        //
        // NOTE: this is intentionally layered ON TOP of LinUCB's native UCB
        // exploration (the alpha * sqrt(x^T A_inv x) term). While theoretically
        // redundant, the ε-greedy wrapper serves two practical purposes:
        //   1. Cold-start tie-breaking: when all theta=0 and all A_inv identical,
        //      the greedy argmax deterministically picks action 0. ε-greedy
        //      ensures all actions get some initial trials.
        //   2. Safety net: LinUCB's UCB can become overconfident if the linear
        //      model assumptions are violated; ε-greedy guarantees a minimum
        //      exploration rate regardless.
        //   3. P1.6: random probes are NEVER suppressed by adaptive
        //      aggressiveness — they are the mechanism for breaking deadlocks.
        // P2.3 FIX: still run predict in exploration mode to keep
        // m_cached_best_score / m_cached_avg_score fresh for downstream
        // consumers (confidence feedback, dynamic degree, suppression gating,
        // and meta-selector confidence query).
        //
        // P3 FIX: previously only featurewise was refreshed; monolithic mode
        // also needs predict() to update m_cached_best_score for the
        // meta-selector get_last_confidence().  Without this, monolithic
        // LinUCB reports stale confidence during exploration steps.
        if (m_featurewise) {
            predict_featurewise(features);  // update caches
        } else {
            // Run predict_with_scores to refresh m_cached_best/avg for
            // confidence queries.  The return value is discarded (we use
            // the random action below), but the cached scores are updated.
            float scores[32];
            m_linucb->predict_with_scores(features, scores,
                                           &m_cached_best_score,
                                           &m_cached_avg_score);
        }
        action_index = m_action_gen(m_rng);
        m_stats.predict.explore++;
    } else {
        // Exploit: use LinUCB prediction (monolithic or feature-wise)
        if (m_featurewise) {
            action_index = predict_featurewise(features);
        } else {
            action_index = m_linucb->predict(features);
        }
        m_stats.predict.exploit++;
        is_exploit = true;
    }

    assert(action_index < m_max_actions);

    // ---- P1.6: Adaptive aggressiveness check (fixed) ----
    //
    // P1.5 DEADLOCK ANALYSIS: The original implementation used a hard
    // deterministic suppression (action = no-prefetch) triggered by a
    // low raw-average reward threshold (-0.05).  During cold start,
    // most early predictions are wrong → reward window fills with
    // negative values → suppression activates → no more prefetches
    // issued → no positive rewards possible → permanent deadlock.
    //
    // P1.6 FIXES:
    //   (a) WARMUP: suppression fully disabled until WARMUP_SAMPLES
    //       (512) accumulate.  Even after warmup, requires at minimum
    //       REWARD_WINDOW (256) samples in the ring buffer.
    //   (b) SOFT suppression: uses probabilistic bias toward action=0,
    //       never deterministic.  Escape probability floor = 5%.
    //   (c) Exploration bypass: ε-greedy random probes are never
    //       suppressed — they are the mechanism for breaking deadlocks.
    //   (d) Positive-ratio metric: tracks the fraction of positive
    //       rewards in the sliding window, which is scale-invariant
    //       and directly measures "is the bandit doing any good?".
    //   (e) Recovery ramp: when positive_ratio improves, suppression
    //       probability smoothly decreases, avoiding hysteresis.
    //
    // Thresholds (tuned to be lenient — only suppress when clearly harmful):
    //   positive_ratio < 0.15  → strong bias toward no-prefetch (80% prob)
    //   positive_ratio < 0.30  → mild bias (40% prob)
    //   positive_ratio >= 0.30 → no suppression
    if (m_actions[action_index] != 0                         // not already no-pref
        && is_exploit)                                       // P1.6(c): not during exploration
    {
        m_stats.suppress.called++;

        // P1.6(a): require warmup before ANY suppression
        if (m_reward_count >= (float)WARMUP_SAMPLES) {

            // P1.6(d): compute positive-reward ratio in sliding window
            float pos_ratio = (m_reward_sum > 0.0f)
                ? m_positive_sum / m_reward_count
                : 0.0f;

            float suppress_prob = 0.0f;

            if (pos_ratio < 0.15f) {
                // Very few positive rewards → strong bias toward no-prefetch
                // But cap at 80% — always leave 20% escape probability
                // so the bandit can re-discover useful prefetch patterns.
                suppress_prob = 0.80f;
            } else if (pos_ratio < 0.30f) {
                // Below-average positive rate → mild bias
                // Linear ramp from 40% at pos_ratio=0.15 to 0% at pos_ratio=0.30
                suppress_prob = 0.40f * (1.0f - (pos_ratio - 0.15f) / 0.15f);
            }
            // pos_ratio >= 0.30: no suppression

            // P1.6(e): probabilistic (never deterministic)
            if (suppress_prob > 0.0f && m_dist(m_rng) < suppress_prob) {
                action_index = m_no_pref_action_idx;
                m_stats.suppress.suppressed++;
            } else if (suppress_prob > 0.0f) {
                m_stats.suppress.suppressed_escape++;
            }
        }
        // else: still in warmup → suppression disabled, let the bandit learn
    }

    // ---- P2.5: UCB score ratio gating (with P2.8 dynamic threshold) ----
    // After P1.6 suppression and normal prediction, check whether the best
    // UCB score significantly exceeds the average.  If all arms have similar
    // scores, there is no clear winner → issuing a prefetch would be random
    // speculation.  This catches the common LinUCB failure mode of ~38M
    // prefetches issued at near-random accuracy.
    //
    // P2.5 COLD-START FIX: During cold start (all theta ≈ 0), all UCB scores
    // are dominated by the exploration bonus term, giving ratio ≈ 1.0 for all
    // actions.  Without warmup protection, the gate would suppress EVERY
    // exploitation attempt → no prefetches → no rewards → permanent deadlock.
    // Fix: (a) gate is disabled until WARMUP_SAMPLES accumulate (same as P1.6);
    // (b) after warmup, a 5% escape probability is retained so the bandit can
    // recover if the model drifts into an over-conservative state.
    //
    // P2.8 DYNAMIC RATIO: The fixed suppress_ratio (default 1.5) is a
    // one-size-fits-all threshold that systematically under-prefetches on
    // highly predictable traces (ligra, lbm) where the bandit achieves >90%
    // accuracy.  We now compute a dynamic threshold from the recent
    // positive-reward ratio (m_positive_sum / m_reward_count):
    //   - pos_ratio > 0.70  → ratio = 1.10  (relaxed: pattern is predictable)
    //   - pos_ratio < 0.30  → ratio = 2.00  (tightened: random access, be conservative)
    //   - otherwise         → ratio = m_suppress_ratio (default from config)
    // This lets the gate automatically relax when the bandit is performing
    // well, recovering coverage that the fixed threshold would suppress.
    //
    // Only applies during exploitation (not ε-greedy probes) and only when
    // the action is not already "no-prefetch".
    if (m_suppress_gating && m_actions[action_index] != 0 && is_exploit) {
        m_stats.predict.gating_checked++;

        // P2.5(a): require warmup — same threshold as P1.6 to give the
        // bandit enough time to accumulate meaningful reward feedback
        // before confidence-based gating activates.
        if (m_reward_count >= (float)WARMUP_SAMPLES) {

            // For monolithic mode, we need to compute scores. For feature-wise
            // mode, scores are already cached from predict_featurewise().
            if (!m_featurewise) {
                // Compute scores on-demand (slight overhead, only when gating is active)
                float scores[32];
                m_linucb->predict_with_scores(features, scores,
                                               &m_cached_best_score, &m_cached_avg_score);
            }

            // Ratio = |best| / (|avg| + ε).  Uses absolute values because
            // UCB scores can be negative in pathological cases; the key
            // question is "does the best action stand out from the pack?"
            // regardless of whether scores are positive or negative.
            float ratio = (m_cached_avg_score > 0.0f || m_cached_avg_score < 0.0f)
                ? fabsf(m_cached_best_score) / (fabsf(m_cached_avg_score) + 1e-8f)
                : 1.0f;

            // P2.8: dynamic gating threshold from recent positive-reward ratio.
            // When the bandit is consistently correct (high pos_ratio), relax
            // the gate to recover coverage.  When accuracy is poor, tighten it.
            float effective_ratio = m_suppress_ratio;  // default from config
            if (m_reward_count > 0.0f) {
                float pos_ratio = m_positive_sum / m_reward_count;
                if (pos_ratio > 0.70f) {
                    effective_ratio = 1.10f;  // relaxed: high-confidence pattern
                } else if (pos_ratio < 0.30f) {
                    effective_ratio = 2.00f;  // tightened: random access suspected
                }
            }

            if (ratio < effective_ratio) {
                // P2.5(b): probabilistic, not deterministic.  95% follow the
                // gate, 5% escape → prevents deadlock if model drifts.
                if (m_dist(m_rng) < 0.95f) {
                    action_index = m_no_pref_action_idx;
                    m_stats.predict.gating_suppressed++;
                }
            }
        }
        // else: still in warmup → gating disabled, let the bandit learn
    }

    // ---- P1.4: Store confidence for next prediction on this page ----
    // Confidence = |expected_reward| for the chosen action.
    //
    // Also always compute normalized confidence for the meta-selector.
    {
        float conf;
        if (m_featurewise) {
            // Use cached best score from pooling
            conf = (m_cached_best_score > 0.0f)
                ? m_cached_best_score / ((float)m_num_feature_models * 0.5f)
                : 0.0f;
            if (conf < 0.0f) conf = 0.0f;
            if (conf > 1.0f) conf = 1.0f;
        } else {
            conf = m_linucb->get_expected_reward(features, action_index);
            if (conf < 0.0f) conf = -conf;  // absolute value
            // Normalize: max expected |reward| ≈ num_features * 0.5
            float conf_max = (float)m_num_features * 0.5f;
            if (conf > conf_max) conf = conf_max;
            conf = conf / (conf_max + 1e-8f);
        }
        // Always store for meta-selector (independent of feature count check)
        m_last_confidence = conf;

        if (m_num_features > 10) {  // only when confidence feature slot exists
            lot_entry.last_confidence = conf;
        }
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
            vector<CBPrefetchTrackerEntry*> existing = search_pt(pf_addr);
            if (existing.empty()) {
                pref_addr.push_back(pf_addr);
                m_stats.predict.issue_dist[action_index]++;

                // Track in PT
                CBPrefetchTrackerEntry* entry =
                    new CBPrefetchTrackerEntry(pf_addr, features,
                                                action_index, m_num_features);
                m_pt.push_back(entry);
                m_stats.pt.insert++;

                // Evict oldest if PT is full
                if (m_pt.size() > m_pt_size) {
                    CBPrefetchTrackerEntry* victim = m_pt.front();
                    m_pt.pop_front();
                    m_stats.pt.evict++;

                    // Compute reward for evicted entry
                    if (!victim->has_reward) {
                        if (victim->is_sentinel) {
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
                // LinUCB expected reward confidence. Only the base (degree-1)
                // prefetch is PT-tracked; extra prefetches are speculative.
                uint32_t dyn_degree = get_dyn_pref_degree(features, action_index);
                m_stats.predict.deg_histogram[dyn_degree]++;
                if (dyn_degree > 1) {
                    gen_multi_degree_pref(page, offset,
                                          m_actions[action_index],
                                          dyn_degree, pref_addr);
                }
            }
        } else {
            // Out-of-bounds: the chosen action would cross a page boundary.
            // We still create a PT entry so the bandit receives complete feedback —
            // otherwise this (state, action) pair is a learning blind spot (never
            // rewarded or penalized). Out-of-bounds entries are treated as incorrect
            // on eviction: the action was invalid in this context.
            m_stats.predict.out_of_bounds++;
            CBPrefetchTrackerEntry* entry =
                new CBPrefetchTrackerEntry(0xdeadbeef, features,
                                            action_index, m_num_features);
            m_pt.push_back(entry);
            m_stats.pt.insert++;

            if (m_pt.size() > m_pt_size) {
                CBPrefetchTrackerEntry* victim = m_pt.front();
                m_pt.pop_front();
                m_stats.pt.evict++;

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
        CBPrefetchTrackerEntry* entry =
            new CBPrefetchTrackerEntry(0xdeadbeef, features,
                                        action_index, m_num_features);
        m_pt.push_back(entry);
        m_stats.pt.insert++;

        if (m_pt.size() > m_pt_size) {
            CBPrefetchTrackerEntry* victim = m_pt.front();
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
}

/* -------------------------------------------------------------------------
 * register_fill(): Called when a prefetched line is filled into the cache
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::register_fill(uint64_t address) {
    m_stats.register_fill.called++;
    vector<CBPrefetchTrackerEntry*> matches = search_pt(address);

    for (auto* entry : matches) {
        entry->is_filled = true;
        m_stats.register_fill.set++;
    }
}

/* -------------------------------------------------------------------------
 * register_prefetch_hit(): Called when a prefetched line is found in cache
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::register_prefetch_hit(uint64_t address) {
    // Reward handled in invoke_prefetcher via PT search
    (void)address;
}

/* -------------------------------------------------------------------------
 * Search PT for entries matching the given address
 * ------------------------------------------------------------------------- */
vector<CBPrefetchTrackerEntry*> ContextualBanditPrefetcher::search_pt(uint64_t address) {
    m_stats.pt.lookup++;
    vector<CBPrefetchTrackerEntry*> result;
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
 *
 * Same reward structure as Tsetlin/Pythia for fair comparison.
 * ------------------------------------------------------------------------- */
int32_t ContextualBanditPrefetcher::compute_reward(
        CBPrefetchTrackerEntry* entry, int32_t reward_type)
{
    (void)entry;
    bool high_bw = is_high_bw();

    switch (reward_type) {
        case REWARD_TIMELY:    return high_bw ? 25 : 20;
        case REWARD_UNTIMELY:  return high_bw ?  6 : 10;
        case REWARD_INCORRECT: return high_bw ? -16 : -8;
        // No-prefetch decisions age out without any demand access hitting the
        // would-be-prefetched location.  Return 0 (neutral) to avoid creating
        // a systematic bias against action 0 — the bandit neither learns to
        // prefer nor avoid no-prefetch; action 0 stays competitive as a
        // fallback when all other actions are performing poorly.
        case REWARD_NONE:      return 0;
        default:               return 0;
    }
}

/* -------------------------------------------------------------------------
 * Train LinUCB from a PT entry's reward
 *
 * The LinUCB update() method uses the raw reward value directly as a scalar
 * feedback signal. This is simpler than Tsetlin's Type I/II feedback —
 * the LinUCB naturally handles continuous rewards via its linear model.
 *
 * Note: we scale the reward to a smaller range [-1, 1] for numerical
 * stability in the online update. The absolute magnitude matters less
 * than the relative differences between actions.
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::train_from_reward(CBPrefetchTrackerEntry* entry) {
    m_stats.learn.called++;

    int32_t raw_reward = entry->reward;
    uint32_t action = entry->action_index;
    int32_t reward_type = entry->reward_type;

    // Special case: REWARD_NONE means the no-prefetch (action=0) PT entry
    // aged out without a demand access hitting the would-be-prefetched
    // location.  This is "correct restraint" — give a small positive reward
    // so the bandit learns when conservatism is appropriate.
    if (reward_type == REWARD_NONE && action == 0) {
        // Small positive reward: +5 → scaled to +0.2 (mild reinforcement)
        float scaled_reward = 5.0f / 25.0f;

        // P1.6: update sliding window and positive-sum tracking
        float old_val = m_reward_ring[m_reward_head];
        m_reward_sum -= old_val;
        m_reward_ring[m_reward_head] = scaled_reward;
        m_reward_sum += scaled_reward;
        m_positive_sum -= (old_val > 0.0f ? 1.0f : 0.0f);
        m_positive_sum += (scaled_reward > 0.0f ? 1.0f : 0.0f);
        m_reward_head = (m_reward_head + 1) % REWARD_WINDOW;
        if (m_reward_count < (float)REWARD_WINDOW) m_reward_count += 1.0f;

        if (m_featurewise) {
            train_featurewise(entry->features, action, scaled_reward);
        } else {
            m_linucb->update(entry->features, action, scaled_reward);
        }
        m_stats.learn.learned_positive++;
        m_stats.reward.reward_per_action[reward_type][action]++;
        return;
    }

    if (raw_reward != 0) {
        // Scale reward to [-1, 1] range for numerical stability
        // Timely=+20 → +0.8, Untimely=+10 → +0.4, Incorrect=-8 → -0.32, etc.
        float scaled_reward = (float)raw_reward / 25.0f;

        // P1.6: Track reward in sliding window for adaptive aggressiveness.
        // Also maintain a separate positive-reward EMA for ratio-based suppression.
        float old_val = m_reward_ring[m_reward_head];
        m_reward_sum -= old_val;
        m_reward_ring[m_reward_head] = scaled_reward;
        m_reward_sum += scaled_reward;

        // P1.6(d): maintain positive-reward running sum
        // Replace old binary contribution with new one
        m_positive_sum -= (old_val > 0.0f ? 1.0f : 0.0f);
        m_positive_sum += (scaled_reward > 0.0f ? 1.0f : 0.0f);

        m_reward_head = (m_reward_head + 1) % REWARD_WINDOW;
        if (m_reward_count < (float)REWARD_WINDOW) {
            // Still filling the ring buffer: count is incremented per sample.
            // positive_sum is also incremented (old_val=0 on first fill, so the
            // "minus old" is a no-op for the initial fill).
            m_reward_count += 1.0f;
        }

        if (m_featurewise) {
            train_featurewise(entry->features, action, scaled_reward);
        } else {
            m_linucb->update(entry->features, action, scaled_reward);
        }

        if (raw_reward > 0) {
            m_stats.learn.learned_positive++;
        } else {
            m_stats.learn.learned_negative++;
        }
    } else {
        m_stats.learn.learn_skipped_no_reward++;
    }

    // Track per-action reward distribution
    if (reward_type >= 0 && reward_type < NUM_REWARD_TYPES) {
        m_stats.reward.reward_per_action[reward_type][action]++;
    }
}

/* -------------------------------------------------------------------------
 * Bandwidth/IPC update callbacks
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::update_bw(uint8_t bw_level) {
    m_bw_level = bw_level;
}

void ContextualBanditPrefetcher::update_ipc(uint8_t ipc) {
    (void)ipc;
}

void ContextualBanditPrefetcher::update_acc(uint32_t acc_level) {
    (void)acc_level;
}

bool ContextualBanditPrefetcher::is_high_bw() const {
    return m_bw_level >= m_high_bw_thresh;
}

/* -------------------------------------------------------------------------
 * Dynamic prefetch degree based on LinUCB expected reward confidence.
 *
 * Uses |expected_reward| as a confidence proxy — higher magnitude means the
 * linear model is more certain about this action's value in this context.
 *
 * Uses separate threshold/degree lists for normal vs high-BW operation.
 * Falls back to degree=1 if no thresholds are configured.
 * ------------------------------------------------------------------------- */
uint32_t ContextualBanditPrefetcher::get_dyn_pref_degree(
        const float* features, uint32_t action_index)
{
    if (!m_enable_dyn_degree) {
        return m_pref_degree;
    }

    // action 0 = "no prefetch" → degree expansion is meaningless.
    // Defensive guard — the caller (invoke_prefetcher) already skips this path,
    // but future callers might not.
    if (action_index < m_max_actions && m_actions[action_index] == 0) {
        return 1;
    }

    float expected;
    if (m_featurewise) {
        // Use cached best score from pooling as confidence proxy
        expected = m_cached_best_score;
    } else {
        expected = m_linucb->get_expected_reward(features, action_index);
    }
    // Clamp to a reasonable range to prevent a single noisy prediction
    // from triggering max degree on garbage features during early training.
    //
    // Lower bound: 0.0 (negative expected_reward for the chosen action is
    // pathological — shouldn't happen after training, but defensive).
    //
    // Upper bound: m_num_features * 0.5.  With d features in [-1,1] and
    // L2-regularized theta, |expected_reward| = |θ^T x| rarely exceeds d/2.
    // The old [0,1] clamp collapsed all well-trained predictions into one
    // bucket, making dynamic degree regulation ineffective once the bandit
    // converged.  This looser bound preserves differentiation between
    // moderately-confident (conf≈1.5) and highly-confident (conf≈3.0) states.
    float conf = (expected < 0.0f) ? -expected : expected;  // abs()
    if (conf < 0.0f) conf = 0.0f;
    float conf_max = (float)m_num_features * 0.5f;
    if (conf > conf_max) conf = conf_max;

    const vector<int32_t>& thresholds = is_high_bw()
        ? m_dyn_deg_thresh_hbw : m_dyn_deg_thresh;
    const vector<int32_t>& degrees = is_high_bw()
        ? m_dyn_deg_values_hbw : m_dyn_deg_values;

    if (thresholds.empty() || degrees.empty()) {
        return 1;  // no thresholds configured → conservative
    }

    // Thresholds are stored as integers representing confidence levels
    // multiplied by 100 (e.g., threshold=30 means conf=0.30 on a [0,1] scale).
    // Normalize conf back to [0,1] before scaling, because conf_max may be
    // larger than 1.0 (e.g., d*0.5 = 5.5 for 11 features). Without this
    // normalization, conf_scaled could reach 550 and permanently overshoot
    // all thresholds, making dynamic degree regulation ineffective.
    float conf_normalized = conf / conf_max;
    int32_t conf_scaled = (int32_t)(conf_normalized * 100.0f);

    for (size_t i = 0; i < thresholds.size() && i < degrees.size(); i++) {
        if (conf_scaled <= thresholds[i]) {
            return (uint32_t)degrees[i];
        }
    }

    // Confidence exceeds all thresholds → use the highest degree
    return (uint32_t)degrees.back();
}

/* -------------------------------------------------------------------------
 * Generate additional prefetch addresses for multi-degree prefetching.
 *
 * Issues extra speculative prefetches at offset + degree * action_delta
 * for degree = 2, 3, ..., pref_degree. Only the base (degree-1) prefetch
 * is PT-tracked; extra prefetches are speculative (same as Pythia).
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::gen_multi_degree_pref(
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

const char* ContextualBanditPrefetcher::get_reward_type_name(int32_t type) const {
    switch (type) {
        case REWARD_TIMELY:    return "timely";
        case REWARD_UNTIMELY:  return "untimely";
        case REWARD_INCORRECT: return "incorrect";
        case REWARD_NONE:      return "none";
        default:               return "unknown";
    }
}

/* -------------------------------------------------------------------------
 * pop_pt_entries(): Remove recently-added PT entries from the back until
 * size == target_size.  Used by MetaSelectorPrefetcher to discard loser
 * PT entries — their predictions were never issued, so they should not
 * accumulate negative (unfilled) feedback.
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::pop_pt_entries(uint32_t target_size)
{
    while (m_pt.size() > target_size) {
        CBPrefetchTrackerEntry* entry = m_pt.back();
        delete entry;
        m_pt.pop_back();
    }
}

/* -------------------------------------------------------------------------
 * print_config(): Output all configuration parameters
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::print_config() {
    cout << "=== Contextual Bandit (LinUCB) Prefetcher Configuration ===" << endl;
    cout << "linucb_num_features " << m_num_features << endl;
    cout << "linucb_num_actions " << m_max_actions << endl;
    cout << "linucb_actions ";
    for (size_t i = 0; i < m_actions.size(); i++) {
        cout << m_actions[i] << (i < m_actions.size()-1 ? "," : "");
    }
    cout << endl;
    cout << "linucb_pt_size " << m_pt_size << endl;
    cout << "linucb_pref_degree " << m_pref_degree << endl;
    cout << "linucb_enable_dyn_degree " << (m_enable_dyn_degree ? "true" : "false") << endl;
    if (m_enable_dyn_degree) {
        cout << "linucb_dyn_deg_thresh ";
        for (size_t i = 0; i < m_dyn_deg_thresh.size(); i++)
            cout << m_dyn_deg_thresh[i] << (i < m_dyn_deg_thresh.size()-1 ? "," : "");
        cout << endl;
        cout << "linucb_dyn_deg_values ";
        for (size_t i = 0; i < m_dyn_deg_values.size(); i++)
            cout << m_dyn_deg_values[i] << (i < m_dyn_deg_values.size()-1 ? "," : "");
        cout << endl;
        cout << "linucb_dyn_deg_thresh_hbw ";
        for (size_t i = 0; i < m_dyn_deg_thresh_hbw.size(); i++)
            cout << m_dyn_deg_thresh_hbw[i] << (i < m_dyn_deg_thresh_hbw.size()-1 ? "," : "");
        cout << endl;
        cout << "linucb_dyn_deg_values_hbw ";
        for (size_t i = 0; i < m_dyn_deg_values_hbw.size(); i++)
            cout << m_dyn_deg_values_hbw[i] << (i < m_dyn_deg_values_hbw.size()-1 ? "," : "");
        cout << endl;
    }
    cout << "linucb_high_bw_thresh " << (int)m_high_bw_thresh << endl;
    cout << "linucb_epsilon " << m_epsilon << endl;
    cout << "linucb_featurewise " << (m_featurewise ? "true" : "false")
         << " (P2.3)" << endl;
    if (m_featurewise) {
        cout << "linucb_featurewise_pooling "
             << (m_lcb_pooling == LCB_POOL_MAX ? "max" : "weighted")
             << " num_models=" << m_num_feature_models
             << " weight_lr=" << m_lcb_weight_lr << endl;
    }
    cout << "linucb_suppress_gating " << (m_suppress_gating ? "true" : "false")
         << " (P2.5)" << endl;
    if (m_suppress_gating) {
        cout << "linucb_suppress_ratio " << m_suppress_ratio << endl;
    }
    cout << "linucb_history_features " << (m_history_features ? "true" : "false")
         << " (P2.6)" << endl;
    cout << endl;
}

/* -------------------------------------------------------------------------
 * dump_stats(): Output all statistics (ChampSim format)
 * ------------------------------------------------------------------------- */
void ContextualBanditPrefetcher::dump_stats() {
    cout << "linucb_pt_lookup " << m_stats.pt.lookup << endl;
    cout << "linucb_pt_hit " << m_stats.pt.hit << endl;
    cout << "linucb_pt_evict " << m_stats.pt.evict << endl;
    cout << "linucb_pt_insert " << m_stats.pt.insert << endl;
    cout << endl;

    cout << "linucb_predict_called " << m_stats.predict.called << endl;
    cout << "linucb_predict_explore " << m_stats.predict.explore << endl;
    cout << "linucb_predict_exploit " << m_stats.predict.exploit << endl;
    cout << "linucb_predict_out_of_bounds " << m_stats.predict.out_of_bounds << endl;
    cout << "linucb_predict_predicted " << m_stats.predict.predicted << endl;
    cout << "linucb_predict_multi_deg_called " << m_stats.predict.multi_deg_called << endl;
    cout << "linucb_predict_multi_deg_issued " << m_stats.predict.multi_deg_issued << endl;
    cout << "linucb_predict_gating_checked " << m_stats.predict.gating_checked << endl;
    cout << "linucb_predict_gating_suppressed " << m_stats.predict.gating_suppressed << endl;

    for (uint32_t i = 0; i < m_max_actions; i++) {
        cout << "linucb_predict_action_" << m_actions[i] << " "
             << m_stats.predict.action_dist[i] << endl;
        cout << "linucb_predict_issue_action_" << m_actions[i] << " "
             << m_stats.predict.issue_dist[i] << endl;
    }
    for (size_t d = 1; d < m_stats.predict.deg_histogram.size(); d++) {
        cout << "linucb_degree_" << d << " " << m_stats.predict.deg_histogram[d] << endl;
    }
    for (size_t d = 2; d < m_stats.predict.multi_deg_histogram.size(); d++) {
        cout << "linucb_multi_deg_" << d << " " << m_stats.predict.multi_deg_histogram[d] << endl;
    }
    cout << endl;

    cout << "linucb_reward_called " << m_stats.reward.called << endl;
    cout << "linucb_reward_pt_not_found " << m_stats.reward.pt_not_found << endl;
    cout << "linucb_reward_pt_found " << m_stats.reward.pt_found << endl;
    cout << "linucb_reward_correct_timely " << m_stats.reward.correct_timely << endl;
    cout << "linucb_reward_correct_untimely " << m_stats.reward.correct_untimely << endl;
    cout << "linucb_reward_incorrect " << m_stats.reward.incorrect << endl;
    cout << "linucb_reward_no_pref " << m_stats.reward.no_pref << endl;
    cout << endl;

    for (uint32_t a = 0; a < m_max_actions; a++) {
        cout << "linucb_reward_" << m_actions[a] << " ";
        for (int r = 0; r < NUM_REWARD_TYPES; r++) {
            cout << m_stats.reward.reward_per_action[r][a] << ",";
        }
        cout << endl;
    }
    cout << endl;

    cout << "linucb_learn_called " << m_stats.learn.called << endl;
    cout << "linucb_learn_positive " << m_stats.learn.learned_positive << endl;
    cout << "linucb_learn_negative " << m_stats.learn.learned_negative << endl;
    cout << "linucb_learn_skipped " << m_stats.learn.learn_skipped_no_reward << endl;
    cout << endl;

    cout << "linucb_suppress_called " << m_stats.suppress.called << endl;
    cout << "linucb_suppress_suppressed " << m_stats.suppress.suppressed << endl;
    cout << "linucb_suppress_prob " << m_stats.suppress.suppressed_prob << endl;
    cout << "linucb_suppress_escape " << m_stats.suppress.suppressed_escape << endl;
    cout << endl;

    cout << "linucb_register_fill_called " << m_stats.register_fill.called << endl;
    cout << "linucb_register_fill_set " << m_stats.register_fill.set << endl;
    cout << endl;

    // Feature-wise stats (P2.3)
    if (m_featurewise) {
        cout << "linucb_featurewise_pooled_predicts " << m_stats.featurewise.pooled_predicts << endl;
        cout << "linucb_featurewise_weight_updates " << m_stats.featurewise.weight_updates << endl;
        for (uint32_t m = 0; m < m_num_feature_models && m < 8; m++) {
            cout << "linucb_featurewise_model_" << m
                 << "_agree " << m_stats.featurewise.model_agrees[m] << endl;
        }
        for (uint32_t m = 0; m < m_num_feature_models && m < 8; m++) {
            cout << "linucb_featurewise_model_" << m
                 << "_weight " << fixed << setprecision(4)
                 << m_feature_models[m].weight << endl;
        }
        cout << endl;
    }

    // LinUCB internal state stats
    if (m_featurewise) {
        for (uint32_t m = 0; m < m_num_feature_models; m++) {
            cout << "--- LinUCB_sub_" << m << " (feat_start="
                 << m_feature_models[m].feat_start
                 << " count=" << m_feature_models[m].feat_count << ") ---" << endl;
            m_feature_models[m].model->dump_state();
        }
    } else {
        m_linucb->dump_state();
    }
}
