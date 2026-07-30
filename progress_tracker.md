# Ibex SoC on GF180MCU — Progress Tracker

Front-end flow: RTL → simulation → synthesized netlist.

**Legend:** ✅ done & verified  🚧 in progress  ⬜ not started
---
## Status at a glance
| Phase | Description | Status |
|-------|-------------|--------|
| A | Foundations & toolchain | ✅ |
| B | Architecture & design | ✅ |
| C | RTL block development | ✅ (19/19) |
| D | Integration | ✅ (v0.1–v0.8, complete SoC) |
| E | Synthesis → netlist | ✅ (fits 1 mm², netlist + timing + gate-sim) |
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

## Phase C — RTL Block Development ✅
| Block | Description | Verification | Status |
|-------|-------------|--------------|--------|
| `sram_bank_2k` | 2 KB bank (4× 512×8 macros) — *superseded by narrow memory in Phase E* | 10 checks, 0 errors | ✅ |
| `fetch_gather` / `imem_narrow` | Narrow 8-bit instruction memory (1× 512×8 + byte-gather fetch) | tb_fetch_gather, tb_imem_narrow_top, 0 errors | ✅ |
| `dmem_narrow` / `ahb_mem` | Narrow 8-bit data memory (1× 64×8 + byte scatter/gather + AHB wait-states) | tb_dmem_narrow, tb_ahb_mem, 0 errors | ✅ |
| `mem_wrapper` | Ibex req/gnt/rvalid → SRAM interface | reads/writes, 0 errors | ✅ |
| `rst_sync` | Two-flop reset synchronizer (async assert, sync de-assert) | timing checks, 0 errors | ✅ |
| `mem_subsystem` | rst_sync + imem + dmem, with scan-load write path | both ports + scan load, 0 errors | ✅ |
| `gpio` | 8-pin GPIO, output reg + 2-flop input synchronizer | 4 checks, 0 errors | ✅ |
| `ibex_to_ahb` | Ibex req/gnt/rvalid → AHB-Lite master adapter | via bus + integration tests | ✅ |
| `ahb_interconnect` | AHB-Lite address decoder + response mux | routing + one-hot, 0 errors | ✅ |
| `ahb_mem` | Data memory as AHB-Lite slave (zero-wait, self-contained) | address-discriminated reads, 0 errors | ✅ |
| `ahb_gpio` | GPIO as AHB-Lite slave (single-tier variant) | via bus tests | ✅ |
| `ahb_to_apb` | AHB → APB bridge | full chain, wait-state verified | ✅ |
| `apb_decoder` | APB address decode / fan-out to GPIO/UART/SPI | multi-peripheral routing, 0 errors | ✅ |
| `apb_gpio` | GPIO as APB slave (two-tier variant) | via bus + integration tests | ✅ |
| `uart` | UART TX + RX, baud generator, separate status/data regs | loopback + bus, 0 errors | ✅ |
| `apb_uart` | UART as APB slave | full chain, 0 errors | ✅ |
| `spi` | SPI master (Mode 0), clock divider + shift FSM | loopback, 0 errors | ✅ |
| `apb_spi` | SPI as APB slave | full chain, 0 errors | ✅ |
| `scan_chain` | Program-loading scan chain (serial shift-in → memory write) | serial load + read-back, 0 errors | ✅ |
| `test_fsm` | Load/run sequencing FSM (gates CPU reset, mem ownership) | full state sequence, 0 errors | ✅ |
| `clk_gen` | Ring-oscillator clock generator | behavioral sim model (real version = physical) | ✅ |

The full two-tier bus (Ibex → AHB-Lite → bridge → APB → peripherals) is verified end-to-end, with GPIO, UART, and SPI on APB at their memory-map addresses.

## Phase D — Integration ✅

Integration proceeds incrementally: each version wires one additional block into the top level and is verified against the **real Ibex core** (not a testbench master) via a self-checking smoke test. Integration smoke tests build with Verilator (Ibex requires it) and run a hand-assembled RV32I program. The GF180 SRAM behavioral model requires a clean power-up (CEN wake-up) before returning data, so the harnesses assert the macros' operational state at reset; this is a simulation bring-up step only — the RTL memory control (`cen = ~cs`) is correct for silicon.

| Milestone | Description | Verification | Status |
|-----------|-------------|--------------|--------|
| v0.1 | Ibex + memory subsystem; CPU executes a program from custom SRAM | `tb_chip_smoke5` — PC advances 0x80→0x8C and loops | ✅ |
| v0.2 | Data path routed through the AHB bus to memory | `tb_chip_v02` — store 0x2A2 to 0x0800, load back matches; adapter write-ack fixed | ✅ |
| v0.3 | GPIO on the bus (AHB → bridge → APB → GPIO) | `tb_chip_v03` — CPU writes 0xA5, gpio_out reaches 0xA5 | ✅ |
| v0.4 | UART on the bus | `tb_chip_v04` — CPU writes 0x41, tx frame decodes to 0x41 | ✅ |
| v0.5 | SPI on the bus; full peripheral set integrated | `tb_chip_v05` — CPU writes 0xB7, MOSI shifts out 0xB7 | ✅ |
| v0.6 | Scan chain + test FSM: chip loads program serially, then runs it | `tb_chip_load` — scan-load, FSM LOAD→RUN, CPU fetches loaded code | ✅ |
| v0.7 | On-chip clock generator drives downstream logic | `tb_clk_gen_top` — generated clock advances a counter, gates cleanly | ✅ |
| v0.8 | Complete SoC: scan-load program drives GPIO + UART + SPI | `tb_chip_full` — one program, all three peripherals verified in one run | ✅ |

## Phase E — Synthesis → Netlist ✅
| Item | Status | Result |
|------|--------|--------|
| Yosys synthesis script (macros black-boxed) | ✅ | `syn_*.ys`, `syn_netlist.ys` |
| Timing/area report | ✅ | `AREA_REPORT.md`, `TIMING_REPORT.md` |
| Setup-violation closure | ✅ | worst slack +113 ns (MET), Fmax ~147 MHz |
| Gate-level simulation (RTL vs. netlist equivalence) | ✅ | `tb/tb_chip_gate.sv` — GPIO/UART/SPI match RTL |
| `chip_top.nl.v` — deliverable netlist | ✅ | 1,235 std cells + Ibex/SRAM black boxes |

### Key result: fits 1 mm²
The chip synthesizes to **0.911 mm² with pads / 0.761 mm² without pads**, under
the 1 mm² target with 8.9% margin. This required a **narrow-memory redesign**:
instruction and data memories are single 8-bit SRAM macros with byte gather/
scatter units (a 32-bit memory needs 4 macros per bank and does not fit). The
full SoC boots and drives GPIO+UART+SPI in both RTL and gate-level simulation.
See `AREA_REPORT.md` and `TIMING_REPORT.md`.
---
## Target specifications
| Parameter | Value |
|-----------|-------|
| CPU | Ibex RV32IMC |
| Memory | Narrow 8-bit: 512 B imem (1×512×8) + 64 B dmem (1×64×8), gather/scatter |
| Peripherals | GPIO, UART, SPI |
| Bus | Two-tier AHB-Lite + APB |
| Process | GF180MCU (180nm) |
| Die area budget | 1000 × 1000 µm (1 mm²) — achieved 0.911 mm² |

## Repository layout

ibex_soc/

├── rtl/ # synthesizable design (.sv)

├── tb/ # self-checking testbenches

├── memory_map.md

└── README.md

## Running a testbench
```bash
iverilog -g2012 -o sim -s tb_sram_bank \
  tb/tb_sram_bank.sv rtl/sram_bank_2k.sv \
  /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram__sram512x8m8wm1.v
vvp sim
```
Integration smoke tests build with Verilator against the full Ibex source list; see the `tb_chip_v0*` and `tb_chip_full` testbenches.
