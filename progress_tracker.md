# Ibex SoC on GF180MCU — Progress Tracker
A from-scratch RISC-V System-on-Chip built on the open-source **GF180MCU (180nm)** process, using the Ibex RV32IMC core. Front-end flow: RTL → simulation → synthesized netlist.
**Legend:** ✅ done & verified  🚧 in progress  ⬜ not started
---
## Status at a glance
| Phase | Description | Status |
|-------|-------------|--------|
| A | Foundations & toolchain | ✅ |
| B | Architecture & design | ✅ |
| C | RTL block development | 🚧 (9/12) |
| D | Integration | 🚧 (v0.1 ✅) |
| E | Synthesis → netlist | ⬜ |
---
## Phase A — Foundations & Toolchain ✅
| Item | Status |
|------|--------|
| SRAM macro characterization (ports, polarity, read latency) | ✅ |
| Toolchain verified (RISC-V GCC, Verilator, GTKWave) | ✅ |
| Ibex Simple System running `hello_test` in simulation | ✅ |
| Instruction trace verified against objdump | ✅ |
| riscv-tests ISA suite | ⬜ (deferred, optional) |
## Phase B — Architecture & Design ✅
| Item | Status |
|------|--------|
| System block diagram | ✅ |
| Memory map definition (`memory_map.md`) | ✅ |
| Design hierarchy (synthesized vs. macro) | ✅ |
| Bus architecture (two-tier AHB-Lite + APB) | ✅ |
## Phase C — RTL Block Development 🚧
| Block | Description | Verification | Status |
|-------|-------------|--------------|--------|
| `sram_bank_2k` | 2 KB bank (4× 512×8 macros, byte-lane writes) | 10 checks, 0 errors | ✅ |
| `mem_wrapper` | Ibex req/gnt/rvalid → SRAM interface | reads/writes, 0 errors | ✅ |
| `rst_sync` | Two-flop reset synchronizer (async assert, sync de-assert) | timing checks, 0 errors | ✅ |
| `mem_subsystem` | rst_sync + 2× (wrapper+bank): imem + dmem | both ports, 0 errors | ✅ |
| `gpio` | 8-pin GPIO, output reg + 2-flop input synchronizer | 4 checks, 0 errors | ✅ |
| `ibex_to_ahb` | Ibex req/gnt/rvalid → AHB-Lite master adapter | via bus tests | ✅ |
| `ahb_interconnect` | AHB-Lite address decoder + response mux | routing + one-hot, 0 errors | ✅ |
| `ahb_mem` | Data memory as AHB-Lite slave (zero-wait) | address-discriminated reads, 0 errors | ✅ |
| `ahb_gpio` | GPIO as AHB-Lite slave (single-tier variant) | via bus tests | ✅ |
| `ahb_to_apb` | AHB → APB bridge | full chain, wait-state verified | ✅ |
| `apb_decoder` | APB address decode / fan-out to GPIO/UART/SPI | multi-peripheral routing, 0 errors | ✅ |
| `apb_gpio` | GPIO as APB slave (two-tier variant) | via bus tests | ✅ |
| `uart` | UART TX + RX, baud generator, separate status/data regs | loopback + bus, 0 errors | ✅ |
| `apb_uart` | UART as APB slave | full chain, 0 errors | ✅ |
| `spi` | SPI master (Mode 0), clock divider + shift FSM | loopback, 0 errors | ✅ |
| `apb_spi` | SPI as APB slave | full chain, 0 errors | ✅ |
| `scan_chain` | 248-cell scan chain (program load) | — | ⬜ |
| `clk_gen` | Ring-oscillator clock generator | — | ⬜ |
| `test_fsm` | Debug gating FSM | — | ⬜ |

The full two-tier bus (Ibex → AHB-Lite → bridge → APB → peripherals) is verified end-to-end, with GPIO, UART, and SPI on APB at their memory-map addresses.

## Phase D — Integration 🚧
| Milestone | Description | Status |
|-----------|-------------|--------|
| v0.1 | Memory subsystem + Ibex — CPU executes a program from custom SRAM | ✅ |
| v0.2 | AHB bus + APB bridge | ⬜ |
| v0.3 | GPIO (C program drives a pin) | ⬜ |
| v0.4 | UART (TX/RX) | ⬜ |
| v0.5 | SPI + LCD | ⬜ |
| v0.6 | Scan chain (load program, run) | ⬜ |
| v0.7 | Clock generator + test FSM | ⬜ |
| v0.8 | Full `chip_top`, multi-function demo | ⬜ |
## Phase E — Synthesis → Netlist ⬜
| Item | Status |
|------|--------|
| Yosys synthesis script (macros black-boxed) | ⬜ |
| Timing/area report | ⬜ |
| Setup-violation closure | ⬜ |
| Gate-level simulation (RTL vs. netlist equivalence) | ⬜ |
| `chip_top.nl.v` — deliverable netlist | ⬜ |
---
## Target specifications
| Parameter | Value |
|-----------|-------|
| CPU | Ibex RV32IMC |
| Memory | 4 KB SRAM (2 KB instruction / 2 KB data) |
| Peripherals | GPIO, UART, SPI |
| Bus | Two-tier AHB-Lite + APB |
| Process | GF180MCU (180nm) |
| Core area budget | 2051 × 2051 µm |
## Repository layout
```
ibex_soc/
├── rtl/    # synthesizable design (.sv)
├── tb/     # self-checking testbenches
├── memory_map.md
└── README.md
```
## Running a testbench
```bash
iverilog -g2012 -o sim -s tb_sram_bank \
  tb/tb_sram_bank.sv rtl/sram_bank_2k.sv \
  /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram__sram512x8m8wm1.v
vvp sim
```
