#!/bin/bash
set -e
export PYTHONPATH="$(pwd):${PYTHONPATH}"
SEEDS="${SEEDS:-42 43 44 45 46}"
echo "random SPI seeds: $SEEDS"
for s in $SEEDS; do
  echo "========== SPI SEED $s =========="
  RANDOM_SEED=$s make COCOTB_TEST_MODULES=test_pyuvm_random_spi
done
echo "=== All random SPI seeds PASSED ==="
