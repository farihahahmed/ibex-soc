#!/usr/bin/env bash
# Honesty freeze – every match-level test must PASS
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export PYTHONPATH="${ROOT}:${PYTHONPATH:-}"
cd "$ROOT"

run() {
  echo ""
  echo "========== $1 =========="
  shift
  "$@"
}

# Chip-level pyuvm
run "chip smoke"   make COCOTB_TEST_MODULES=test_pyuvm_smoke
run "chip random"  make COCOTB_TEST_MODULES=test_pyuvm_random
run "chip primes"  make COCOTB_TEST_MODULES=test_pyuvm_primes
run "chip piezo"   make COCOTB_TEST_MODULES=test_pyuvm_piezo
run "chip game"    make COCOTB_TEST_MODULES=test_pyuvm_game
run "chip crc32"   make COCOTB_TEST_MODULES=test_pyuvm_crc
run "chip dmem"    make COCOTB_TEST_MODULES=test_pyuvm_dmem

# Control / debug paths
run "scan readback"  make COCOTB_TEST_MODULES=test_scan_readback
run "scan status"    make COCOTB_TEST_MODULES=test_scan_status
run "clk generator"  make COCOTB_TEST_MODULES=test_clkgen
run "fsm countdown"  make COCOTB_TEST_MODULES=test_pyuvm_countdown
run "scan lockout"   make COCOTB_TEST_MODULES=test_pyuvm_scan_lockout

# Block MDV
run "block uart smoke"  bash -c 'cd block/uart && make MODULE=test_uart_smoke COCOTB_TEST_MODULES=test_uart_smoke'
(cd block/gpio && make MODULE=test_gpio_smoke COCOTB_TEST_MODULES=test_gpio_smoke)
(cd block/gpio && make MODULE=test_gpio_write COCOTB_TEST_MODULES=test_gpio_write)
(cd block/spi  && make MODULE=test_spi_smoke  COCOTB_TEST_MODULES=test_spi_smoke)
(cd block/spi  && make MODULE=test_spi_tx     COCOTB_TEST_MODULES=test_spi_tx)

echo ""
echo "=== HONESTY FREEZE: ALL PASSED ==="
