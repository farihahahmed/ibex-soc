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
run "chip pcpi"    make COCOTB_TEST_MODULES=test_pyuvm_pcpi

# Negative, corner and stress tests. These were written earlier but were not
# in the official gate; every one that passes is now included, so the gate
# covers the hard cases rather than only the happy path.
run "illegal addr"   make COCOTB_TEST_MODULES=test_pyuvm_illegal_addr
run "concurrent"     make COCOTB_TEST_MODULES=test_pyuvm_concurrent
run "dmem stress"    make COCOTB_TEST_MODULES=test_pyuvm_dmem_stress
run "uart rx e2e"    make COCOTB_TEST_MODULES=test_pyuvm_uart_rx_e2e
run "uart rx"        make COCOTB_TEST_MODULES=test_pyuvm_uart_rx
run "scan corner"    make COCOTB_TEST_MODULES=test_pyuvm_scan_corner
run "scan corners"   make COCOTB_TEST_MODULES=test_pyuvm_scan_corners
run "sys corner"     make COCOTB_TEST_MODULES=test_pyuvm_sys_corner
run "rerun"          make COCOTB_TEST_MODULES=test_pyuvm_rerun
run "random uart"    make COCOTB_TEST_MODULES=test_pyuvm_random_uart
run "random spi"     make COCOTB_TEST_MODULES=test_pyuvm_random_spi
# Scoreboard self-check - expect_fail, so it passes only when the checker
# catches a deliberately wrong expectation. Guards against an always-green SB.
run "neg gpio"       make COCOTB_TEST_MODULES=test_pyuvm_neg_gpio
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
