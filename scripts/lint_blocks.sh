#!/usr/bin/env bash
# Per-block elaboration check. Catches unconnected ports and elaboration
# errors in seconds, without running a simulation.
set -u
cd "$(dirname "$0")/.."
BLOCKS="uart spi gpio scan_chain test_fsm clk_gen apb_uart apb_spi apb_gpio
        ahb_interconnect ahb_to_apb apb_decoder ibex_to_ahb pico_shim
        fetch_gather imem_narrow_top dmem_narrow_top mem_subsystem
        ahb_mem rst_sync pcpi_custom chip_top_full"
FAIL=0
for m in $BLOCKS; do
  out=$(iverilog -g2012 -o /dev/null -s "$m" \
        synthesis/sram_blackbox.v \
        verification/cocotb/models/gf180mcu_fd_sc_mcu7t5v0__icgtp_1.v \
        rtl/*.sv rtl/picorv32.v 2>&1 | grep -v "sorry:")
  if [ -n "$out" ]; then
    printf "%-20s FAIL\n%s\n" "$m" "$out"; FAIL=1
  else
    printf "%-20s ok\n" "$m"
  fi
done
[ $FAIL -eq 0 ] && echo "=== ALL BLOCKS LINT CLEAN ===" || echo "=== LINT FAILURES ==="
exit $FAIL
