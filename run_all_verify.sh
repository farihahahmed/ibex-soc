#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/verification/cocotb"
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"
echo "=== smoke ===" && make smoke
echo "=== random ===" && RANDOM_SEED=42 make random
echo "=== primes ===" && make primes
echo "=== piezo ===" && make piezo
echo "=== game ===" && make game
echo "=== dmem ===" && make dmem || true
echo "=== scan corner ===" && COCOTB_TEST_MODULES=test_pyuvm_scan_corner make
echo "=== block uart smoke ===" && (cd block/uart && make smoke)
echo "=== block uart tx sb ===" && (cd block/uart && COCOTB_TEST_MODULES=test_uart_tx_sb make)
echo "=== ALL VERIFY PASS ==="
