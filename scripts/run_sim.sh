#!/usr/bin/env bash
# ============================================================================
# Script: run_sim.sh
# Project: 16-Bit Direct-Mapped Cache Controller
# Description: Automates Icarus Verilog compilation, execution, and waveform
#              dump generation.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "============================================================================"
echo " Compiling 16-Bit Direct-Mapped Cache Controller Simulation..."
echo "============================================================================"

mkdir -p simulation/logs simulation/waveforms simulation/results

# Check for iverilog
if ! command -v iverilog &> /dev/null; then
    echo "[ERROR] 'iverilog' command not found."
    echo "To install Icarus Verilog on macOS, run:"
    echo "    brew install icarus-verilog"
    echo ""
    echo "Running Python-based cycle-accurate verification engine instead..."
    python3 scripts/simulate_cache.py
    exit 0
fi

# Compile Verilog-2001 sources
iverilog -g2001 \
    -o simulation/cache_sim \
    rtl/cache_memory.v \
    rtl/main_memory.v \
    rtl/cache_controller.v \
    rtl/direct_mapped_cache.v \
    testbench/cache_tb.v

echo "[INFO] Compilation successful. Running VVP simulation..."
echo ""

# Run VVP and log results
vvp simulation/cache_sim | tee simulation/logs/simulation.log

echo ""
echo "[INFO] Simulation completed. Waveform written to: simulation/waveforms/cache_sim.vcd"
echo "To view waveforms in GTKWave, run:"
echo "    gtkwave simulation/waveforms/cache_sim.vcd"
