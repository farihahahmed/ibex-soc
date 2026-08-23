#!/bin/bash
set -e
SEEDS=${SEEDS:-"42 43 44 45 46"}
export PYTHONPATH="$(pwd):${PYTHONPATH}"

echo "pyuvm constrained-random seeds: $SEEDS"
for seed in $SEEDS; do
  echo ""
  echo "========== SEED $seed =========="
  RANDOM_SEED=$seed COCOTB_TEST_MODULES=test_pyuvm_random make
done
echo ""
echo "=== All pyuvm random seeds PASSED ==="
