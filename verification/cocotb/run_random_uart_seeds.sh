#!/bin/bash
set -e
export PYTHONPATH="$(pwd):${PYTHONPATH}"
SEEDS="${SEEDS:-42 43 44 45 46}"
echo "random UART seeds: $SEEDS"
for s in $SEEDS; do
  echo "========== UART SEED $s =========="
  RANDOM_SEED=$s make COCOTB_TEST_MODULES=test_pyuvm_random_uart
done
echo "=== All random UART seeds PASSED ==="
