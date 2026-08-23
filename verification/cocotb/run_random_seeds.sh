#!/bin/bash
set -e
SEEDS=${SEEDS:-"42 43 44 45 46"}

echo "Running constrained-random with seeds: $SEEDS"
for seed in $SEEDS; do
  echo ""
  echo "========== SEED $seed =========="
  RANDOM_SEED=$seed make random
done
echo ""
echo "=== All seeds PASSED ==="
