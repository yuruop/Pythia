/*
 * Contextual Bandit (LinUCB) Prefetcher - L2 Cache Wrapper
 *
 * Integrates the LinUCB contextual bandit prefetcher into ChampSim's CACHE
 * class for L2 cache prefetching. This wrapper is copied to l2c_prefetcher.cc
 * during the build process.
 *
 * Build usage:
 *   ./build_champsim.sh no linucb no 1
 */

#include <string>
#include <vector>
#include <algorithm>
#include "cache.h"
#include "prefetcher.h"
#include "linucb.h"

using namespace std;

// ---- Knob overrides (from config/linucb.ini) ----
namespace knob {
    extern uint32_t linucb_num_actions;
    extern uint32_t linucb_num_features;
    extern float    linucb_alpha;
    extern float    linucb_lambda;
    extern uint64_t linucb_seed;
    extern vector<int32_t> linucb_actions;
    extern uint32_t linucb_pt_size;
    extern uint32_t linucb_pref_degree;
    extern float    linucb_epsilon;
    extern uint32_t linucb_high_bw_thresh;
    extern uint32_t linucb_rng_seed;
}

// ---- Global LinUCB configuration ----

static LinUCB::Config make_cb_config() {
    LinUCB::Config cfg;
    cfg.num_actions  = knob::linucb_num_actions;
    cfg.num_features = knob::linucb_num_features;
    cfg.alpha        = knob::linucb_alpha;
    cfg.lambda_      = knob::linucb_lambda;
    cfg.seed         = knob::linucb_seed;
    return cfg;
}

// ---- Action space ----
static vector<int32_t> make_actions() {
    if (!knob::linucb_actions.empty()) {
        return knob::linucb_actions;
    }
    // Default action space (same as Pythia's)
    return {1, 3, 4, 5, 10, 11, 12, 22, 23, 30, 32, -1, -3, -6, 0};
}

// ---- Singleton prefetcher instance ----
static ContextualBanditPrefetcher* linucb_pref = nullptr;

/* =========================================================================
 * CACHE Integration Methods
 * ========================================================================= */

void CACHE::l2c_prefetcher_initialize()
{
    cout << "Initializing Contextual Bandit (LinUCB) L2C Prefetcher..." << endl;

    LinUCB::Config cb_cfg = make_cb_config();
    vector<int32_t> actions = make_actions();

    // Update num_actions from the actual action vector
    cb_cfg.num_actions = (uint32_t)actions.size();

    linucb_pref = new ContextualBanditPrefetcher(
        cb_cfg, actions,
        knob::linucb_pt_size,
        knob::linucb_pref_degree,
        knob::linucb_epsilon,
        (uint8_t)knob::linucb_high_bw_thresh,
        knob::linucb_rng_seed,
        "linucb"
    );

    // Storage estimate
    uint32_t d = cb_cfg.num_features;
    uint32_t k = cb_cfg.num_actions;
    float mat_kb = (k * d * d * sizeof(float)) / 1024.0f;
    float vec_kb = (k * d * 2 * sizeof(float)) / 1024.0f;  // theta + b
    float pt_kb = (knob::linucb_pt_size * 10) / 1024.0f;

    cout << "  LinUCB: " << d << " features, "
         << k << " actions, "
         << "alpha=" << cb_cfg.alpha << ", "
         << "lambda=" << cb_cfg.lambda_ << endl;
    cout << "  Storage: ~"
         << (mat_kb + vec_kb) << " KB (A_inv + theta/b)"
         << " + ~" << pt_kb << " KB (PT)"
         << " = ~" << (mat_kb + vec_kb + pt_kb) << " KB total" << endl;
    cout << "  Actions: ";
    for (size_t i = 0; i < actions.size(); i++) {
        cout << actions[i] << (i < actions.size()-1 ? "," : "");
    }
    cout << endl;
    cout << "Contextual Bandit L2C Prefetcher ready." << endl;
}

uint32_t CACHE::l2c_prefetcher_operate(uint64_t addr, uint64_t ip,
                                        uint8_t cache_hit, uint8_t type,
                                        uint32_t metadata_in)
{
    if (linucb_pref == nullptr) return metadata_in;

    vector<uint64_t> pref_addr;
    linucb_pref->invoke_prefetcher(ip, addr, cache_hit, type, pref_addr);

    // Issue prefetch requests to L2
    for (uint64_t pf_addr : pref_addr) {
        prefetch_line(ip, addr, pf_addr, FILL_L2, 0);
    }

    return metadata_in;
}

uint32_t CACHE::l2c_prefetcher_cache_fill(uint64_t addr, uint32_t set,
                                           uint32_t way, uint8_t prefetch,
                                           uint64_t evicted_addr,
                                           uint32_t metadata_in)
{
    if (linucb_pref != nullptr && prefetch) {
        linucb_pref->register_fill(addr);
    }
    return metadata_in;
}

uint32_t CACHE::l2c_prefetcher_prefetch_hit(uint64_t addr, uint64_t ip,
                                             uint32_t metadata_in)
{
    if (linucb_pref != nullptr) {
        linucb_pref->register_prefetch_hit(addr);
    }
    return metadata_in;
}

void CACHE::l2c_prefetcher_final_stats()
{
    if (linucb_pref != nullptr) {
        linucb_pref->dump_stats();
    }
}

void CACHE::l2c_prefetcher_print_config()
{
    if (linucb_pref != nullptr) {
        linucb_pref->print_config();
    }
}

void CACHE::l2c_prefetcher_broadcast_bw(uint8_t bw_level)
{
    if (linucb_pref != nullptr) {
        linucb_pref->update_bw(bw_level);
    }
}

void CACHE::l2c_prefetcher_broadcast_ipc(uint8_t ipc)
{
    if (linucb_pref != nullptr) {
        linucb_pref->update_ipc(ipc);
    }
}

void CACHE::l2c_prefetcher_broadcast_acc(uint32_t acc_level)
{
    if (linucb_pref != nullptr) {
        linucb_pref->update_acc(acc_level);
    }
}
