#!/bin/bash
# =============================================================================
# Setup Parameter Sweep for Tsetlin & LinUCB
#
# Builds both binaries and generates job files for local parallel execution.
#
# Usage:
#   source setvars.sh
#   bash scripts/setup_param_sweep.sh
#
# This will:
#   1. Build tsetlin binary  → bin/perceptron-no-tsetlin-no-ship-1core.exe
#   2. Build linucb binary   → bin/perceptron-no-linucb-no-ship-1core.exe
#   3. Generate run_tsetlin_sweep.sh
#   4. Generate run_linucb_sweep.sh
# =============================================================================
set -e

if [ -z "$PYTHIA_HOME" ]; then
    echo "Error: \$PYTHIA_HOME is not set. Please run: source setvars.sh"
    exit 1
fi

NCORES=${1:-4}  # default 4 parallel jobs

echo "============================================"
echo " Step 1/4: Building Tsetlin binary"
echo "============================================"
cd "$PYTHIA_HOME"
bash build_champsim.sh no tsetlin no 1
echo "  -> Done: bin/perceptron-no-tsetlin-no-ship-1core.exe"

echo ""
echo "============================================"
echo " Step 2/4: Building LinUCB binary"
echo "============================================"
bash build_champsim.sh no linucb no 1
echo "  -> Done: bin/perceptron-no-linucb-no-ship-1core.exe"

echo ""
echo "============================================"
echo " Step 3/4: Generating Tsetlin job file"
echo "============================================"
perl scripts/create_jobfile.pl \
    --exe "$PYTHIA_HOME/bin/perceptron-no-tsetlin-no-ship-1core.exe" \
    --exp "$PYTHIA_HOME/experiments/param_sweep_tsetlin_1C.exp" \
    --tlist "$PYTHIA_HOME/experiments/param_sweep_1C.tlist" \
    --local 1 \
    --ncores "$NCORES" \
    > "$PYTHIA_HOME/run_tsetlin_sweep.sh"
chmod +x "$PYTHIA_HOME/run_tsetlin_sweep.sh"
echo "  -> Done: run_tsetlin_sweep.sh"

echo ""
echo "============================================"
echo " Step 4/4: Generating LinUCB job file"
echo "============================================"
perl scripts/create_jobfile.pl \
    --exe "$PYTHIA_HOME/bin/perceptron-no-linucb-no-ship-1core.exe" \
    --exp "$PYTHIA_HOME/experiments/param_sweep_linucb_1C.exp" \
    --tlist "$PYTHIA_HOME/experiments/param_sweep_1C.tlist" \
    --local 1 \
    --ncores "$NCORES" \
    > "$PYTHIA_HOME/run_linucb_sweep.sh"
chmod +x "$PYTHIA_HOME/run_linucb_sweep.sh"
echo "  -> Done: run_linucb_sweep.sh"

echo ""
echo "============================================"
echo " Setup complete!"
echo "============================================"
echo ""
echo "To run the Tsetlin parameter sweep:"
echo "  bash run_tsetlin_sweep.sh"
echo ""
echo "To run the LinUCB parameter sweep:"
echo "  bash run_linucb_sweep.sh"
echo ""
echo "Output files will be named: {trace}_{experiment}.out"
echo "  e.g., cassandra_phase0_core0_tsetlin_s5.0.out"
echo ""
echo "To collect results after runs complete:"
echo "  python scripts/rollup.py --tlist experiments/param_sweep_1C.tlist \\"
echo "      --exp experiments/param_sweep_tsetlin_1C.exp > results_tsetlin.csv"
echo "  python scripts/rollup.py --tlist experiments/param_sweep_1C.tlist \\"
echo "      --exp experiments/param_sweep_linucb_1C.exp > results_linucb.csv"
