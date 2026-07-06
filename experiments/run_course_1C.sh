#!/bin/bash
#
#
#
# Traces:
#    403.gcc-16B
#    429.mcf-184B
#    433.milc-127B
#    450.soplex-247B
#    462.libquantum-1343B
#    470.lbm-1274B
#    471.omnetpp-188B
#    473.astar-359B
#    483.xalancbmk-127B
#    602.gcc_s-1850B
#    605.mcf_s-994B
#    620.omnetpp_s-141B
#    ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M
#    ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M
#    ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M
#    parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M
#    parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M
#    cassandra_phase0_core0
#    nutch_phase0_core0
#    streaming_phase0_core1
#
#
# Experiments:
#    nopref: --warmup_instructions=20000000 --simulation_instructions=100000000 --config=$(PYTHIA_HOME)/config/nopref.ini
#    spp: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=$(PYTHIA_HOME)/config/spp_dev2.ini
#    bingo: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=$(PYTHIA_HOME)/config/bingo.ini
#    mlop: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=$(PYTHIA_HOME)/config/mlop.ini
#    pythia: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=$(PYTHIA_HOME)/config/pythia.ini
#    linucb: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=$(PYTHIA_HOME)/config/linucb.ini
#    tsetlin: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=$(PYTHIA_HOME)/config/tsetlin.ini
#    nopref_MTPS600: --warmup_instructions=20000000 --simulation_instructions=100000000 --config=$(PYTHIA_HOME)/config/nopref.ini --dram_io_freq=600
#    spp_MTPS600: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=$(PYTHIA_HOME)/config/spp_dev2.ini --dram_io_freq=600
#    bingo_MTPS600: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=$(PYTHIA_HOME)/config/bingo.ini --dram_io_freq=600
#    mlop_MTPS600: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=$(PYTHIA_HOME)/config/mlop.ini --dram_io_freq=600
#    pythia_MTPS600: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=$(PYTHIA_HOME)/config/pythia.ini --dram_io_freq=600
#    linucb_MTPS600: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=$(PYTHIA_HOME)/config/linucb.ini --dram_io_freq=600
#    tsetlin_MTPS600: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=$(PYTHIA_HOME)/config/tsetlin.ini --dram_io_freq=600
#    nopref_MTPS4800: --warmup_instructions=20000000 --simulation_instructions=100000000 --config=$(PYTHIA_HOME)/config/nopref.ini --dram_io_freq=4800
#    spp_MTPS4800: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=$(PYTHIA_HOME)/config/spp_dev2.ini --dram_io_freq=4800
#    bingo_MTPS4800: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=$(PYTHIA_HOME)/config/bingo.ini --dram_io_freq=4800
#    mlop_MTPS4800: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=$(PYTHIA_HOME)/config/mlop.ini --dram_io_freq=4800
#    pythia_MTPS4800: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=$(PYTHIA_HOME)/config/pythia.ini --dram_io_freq=4800
#    linucb_MTPS4800: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=$(PYTHIA_HOME)/config/linucb.ini --dram_io_freq=4800
#    tsetlin_MTPS4800: --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=$(PYTHIA_HOME)/config/tsetlin.ini --dram_io_freq=4800
#
# Parallel execution: up to 20 job(s) at a time
#
#
#
# Total jobs: 420

MAX_PROCS=20
pids=()

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/403.gcc-16B.champsimtrace.xz > 403.gcc-16B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/429.mcf-184B.champsimtrace.xz > 429.mcf-184B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/433.milc-127B.champsimtrace.xz > 433.milc-127B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/450.soplex-247B.champsimtrace.xz > 450.soplex-247B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/462.libquantum-1343B.champsimtrace.xz > 462.libquantum-1343B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/470.lbm-1274B.champsimtrace.xz > 470.lbm-1274B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/471.omnetpp-188B.champsimtrace.xz > 471.omnetpp-188B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/473.astar-359B.champsimtrace.xz > 473.astar-359B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/483.xalancbmk-127B.champsimtrace.xz > 483.xalancbmk-127B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/602.gcc_s-1850B.champsimtrace.xz > 602.gcc_s-1850B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/605.mcf_s-994B.champsimtrace.xz > 605.mcf_s-994B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800  -traces /workspace/traces/620.omnetpp_s-141B.champsimtrace.xz > 620.omnetpp_s-141B_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_BFS.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M.champsimtrace.xz > ligra_PageRank.com-lj.ungraph.gcc_6.3.0_O3.drop_500M.length_250M_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/ligra/ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M.champsimtrace.xz > ligra_Triangle.com-lj.ungraph.gcc_6.3.0_O3.drop_3500M.length_250M_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M.champsimtrace.xz > parsec_2.1.canneal.simlarge.prebuilt.drop_1250M.length_250M_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800 --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/parsec2.1/parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M.champsimtrace.xz > parsec_2.1.streamcluster.simlarge.prebuilt.drop_0M.length_250M_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/cassandra_phase0_core0.trace.xz > cassandra_phase0_core0_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/nutch_phase0_core0.trace.xz > nutch_phase0_core0_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_nopref.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_spp.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_bingo.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_mlop.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_pythia.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_linucb.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_tsetlin.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_nopref_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_spp_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_bingo_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_mlop_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_pythia_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_linucb_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=600 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_tsetlin_MTPS600.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --config=/workspace/config/nopref.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_nopref_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=spp_dev2 --config=/workspace/config/spp_dev2.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_spp_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=bingo --config=/workspace/config/bingo.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_bingo_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=mlop --config=/workspace/config/mlop.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_mlop_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=scooby --config=/workspace/config/pythia.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_pythia_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=linucb --config=/workspace/config/linucb.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_linucb_MTPS4800.out 2>&1' &
pids+=($!)

while [ ${#pids[@]} -ge $MAX_PROCS ]; do
    for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[$i]'
        fi
    done
    pids=("${pids[@]}")
    [ ${#pids[@]} -ge $MAX_PROCS ] && sleep 1
done
eval '/workspace/bin/perceptron-multi-multi-no-ship-1core --warmup_instructions=20000000 --simulation_instructions=100000000 --l2c_prefetcher_types=tsetlin --config=/workspace/config/tsetlin.ini --dram_io_freq=4800 --knob_cloudsuite=true --warmup_instructions=10000000 --simulation_instructions=40000000 -traces /workspace/traces/streaming_phase0_core1.trace.xz > streaming_phase0_core1_tsetlin_MTPS4800.out 2>&1' &
pids+=($!)

# Wait for remaining jobs to finish
wait
echo "All jobs done."
