#!/bin/bash
set -euo pipefail
export PYTHONPATH="/foss/designs/pico_soc/verification/cocotb:${PYTHONPATH:-}"
ROOT=/foss/designs/pico_soc/verification/cocotb

run() {
  local dir=$1
  echo "=== $dir :: block-regress ==="
  (cd "$ROOT/$dir" && make block-regress)
}

run block/uart
run block/gpio
run block/spi
run block/mem
run block/fsm
run block/scan
run block/scan_fsm
run block/ahb
run block/clkgen
run block/ahb_to_apb
run block/apb_decoder

echo "=== ALL BLOCK MDV PASS ==="
