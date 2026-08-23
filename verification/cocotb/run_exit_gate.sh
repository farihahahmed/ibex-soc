#!/bin/bash
# Full verification exit gate for Pico SoC
set -euo pipefail
export PYTHONPATH="/foss/designs/ibex_soc/verification/cocotb:${PYTHONPATH:-}"
ROOT=/foss/designs/ibex_soc/verification/cocotb
cd "$ROOT"

echo "############################################"
echo "# 1/3  BLOCK MDV"
echo "############################################"
./run_block_regress.sh

echo ""
echo "############################################"
echo "# 2/3  CHIP-LEVEL pyuvm"
echo "############################################"
make pyuvm-regress

echo ""
echo "############################################"
echo "# 3/3  FUNCTIONAL COVERAGE MERGE"
echo "############################################"
if [ -f merge_coverage.py ]; then
  python3 merge_coverage.py
else
  echo "(merge_coverage.py not present – skip)"
fi

echo ""
echo "############################################"
echo "# EXIT GATE: ALL PASS"
echo "############################################"
