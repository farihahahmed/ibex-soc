#!/usr/bin/env bash
# Full Pico SoC verification regress (chip + block + formal)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COCOTB="$ROOT/verification/cocotb"
export PYTHONPATH="$COCOTB:${PYTHONPATH:-}"

fail=0
run() {
  local name="$1"; shift
  echo ""
  echo "========== $name =========="
  if "$@"; then
    echo "OK: $name"
  else
    echo "FAIL: $name"
    fail=1
  fi
}
cd "$COCOTB"
run "chip smoke"   make COCOTB_TEST_MODULES=test_pyuvm_smoke
run "chip random"  make COCOTB_TEST_MODULES=test_pyuvm_random
run "chip primes"  make COCOTB_TEST_MODULES=test_pyuvm_primes
run "chip piezo"   make COCOTB_TEST_MODULES=test_pyuvm_piezo
run "chip game"    make COCOTB_TEST_MODULES=test_pyuvm_game
run "chip dmem"    make COCOTB_TEST_MODULES=test_pyuvm_dmem
cd "$COCOTB/block/uart"
run "block uart smoke" make smoke
run "block uart tx"    make tx 2>/dev/null || make COCOTB_TEST_MODULES=test_uart_tx
cd "$COCOTB/block/spi"
run "block spi smoke"    make smoke
run "block spi tx"       make tx
run "block spi loopback" make loopback
cd "$ROOT"
run "formal test_fsm"    python3 verification/formal/run_test_fsm_formal.py
run "formal scan_chain"  python3 verification/formal/run_scan_chain_formal.py
echo ""
if [[ $fail -eq 0 ]]; then
run "rtl coverage gate" python3 scripts/report_rtl_coverage.py
  echo "=== FULL REGRESS PASSED ==="
  exit 0
else
  echo "=== FULL REGRESS FAILED ==="
  exit 1
fi
