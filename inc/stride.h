#ifndef STRIDE_H
#define STRIDE_H

#include <deque>
#include <vector>
#include "prefetcher.h"

using namespace std;

class Tracker
{
  public:
    uint64_t pc;
    uint64_t last_cl_addr;
    int64_t last_stride;
    uint32_t consecutive_matches;  // P3: streak for confidence ramp-up

    Tracker()
    {
        pc = 0;
        last_cl_addr = 0;
        last_stride = 0;
        consecutive_matches = 0;
    };
};

class StridePrefetcher : public Prefetcher
{
private:
   deque<Tracker*> trackers;

   /* stats */
   struct
   {
      struct
      {
         uint64_t lookup;
         uint64_t evict;
         uint64_t insert;
         uint64_t hit;
      } tracker;

      struct
      {
         uint64_t pos;
         uint64_t neg;
         uint64_t zero;
      } stride;

      struct
      {
         uint64_t stride_match;
         uint64_t generated;
      } pref;

   } stats;

   // Confidence for meta-selector: streak-based, ramps from 0→1 over 8
   // consecutive matches.  Prevents EMA asymmetry: a single match no longer
   // inflates norm_conf to 100×, and a single mismatch resets to 0.
   static constexpr uint32_t STRIDE_CONF_STREAK_MAX = 8;
   float m_last_confidence;

private:
   void init_knobs();
   void init_stats();
   uint32_t generate_prefetch(uint64_t address, int32_t stride, vector<uint64_t> &pref_addr);

public:
   StridePrefetcher(string type);
   ~StridePrefetcher();
   void invoke_prefetcher(uint64_t pc, uint64_t address, uint8_t cache_hit, uint8_t type, vector<uint64_t> &pref_addr);
   void dump_stats();
   void print_config();

   // Query the confidence of the last prediction.
   // Returns 1.0 if the last invocation confirmed a stride match (high confidence),
   // 0.0 if no stride was detected or stride didn't match.
   float get_last_confidence() const { return m_last_confidence; }
};


#endif /* STRIDE_H */
