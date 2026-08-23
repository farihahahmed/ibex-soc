# Pico SoC Verification Plan

## 1. Scope
DUT: chip_top_full — PicoRV32 SoC with scan boot, narrow imem/dmem,
GPIO, UART, SPI, test FSM (IDLE / RUN / COUNTDOWN), GF180MCU target.

Goals:
- Prove functional correctness of boot, peripherals, and firmware demos
- Block-level MDV for UART, GPIO, SPI
- Gate-level smoke on post-PnR netlist
- Coverage: functional flow + glue RTL line >= ~70% (exclude CPU + SRAM models)

## 2. DUT hierarchy

chip_top_full
  scan_chain          (program / FSM / clkgen load)
  test_fsm            (cpu_clk gate, scan_owns_mem)
  picorv32 + pico_shim
  mem_subsystem       (narrow imem 256B, dmem 64B)
  ahb_interconnect
  apb_* (gpio, uart, spi)
  pad / power (GL)

Block DUTs (isolated):
- apb_uart + uart
- apb_gpio / gpio path
- apb_spi / spi path

## 3. Phases

| Phase | Focus | Exit criterion |
|------:|-------|----------------|
| 0 | Env, models, smoke compile | DUT elaborates; reset + clock |
| 1 | Directed chip smoke | GPIO/UART/SPI match golden |
| 2 | pyuvm agents + scoreboard | Flow events + SB PASS |
| 3 | Constrained-random multi-seed | >=5 unique GPIO bins; seeds pass |
| 4 | Firmware (primes, piezo, game) | Self-check or activity PASS |
| 5 | Block MDV (UART, GPIO, SPI) | Predictor SB PASS + block cov |
| 6 | dmem / narrow-mem directed | SW/LW observed on GPIO |
| 7 | Gate-level smoke | Post-PnR netlist runs |
| 8 | System corners (scan/reset/concurrent) | Documented PASS tests |
| 9 | Freeze | Plan + regress green + logs |

## 4. Official gates (must stay green)

cd verification/cocotb
export PYTHONPATH="$(pwd):${PYTHONPATH}"
make pyuvm-regress
make lint
make gl
make -C block/uart smoke

## 5. Out of scope (honest)
- Full SDF timing annotation on GL
- 95% toggle including picorv32 + SRAM macros
- Formal / formal-equivalence (unless added later)

## 6. Tools
- Simulator: Icarus (functional), Verilator (line coverage model)
- Methodology: cocotb + pyuvm
- Build: Make + FuseSoC (::pico_soc:1.0.0)
- PDK cells for GL: gf180mcu_fd_sc_mcu7t5v0 + SRAM behavioral

## 7. Sign-off
Exit when: gates above PASS, this plan + requirements table + architecture
diagram exist, and no fail_ok in the official regress.
