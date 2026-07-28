# Ibex SoC on GF180MCU — Progress Tracker

A from-scratch RISC-V System-on-Chip built on the open-source **GF180MCU (180nm)** process, using the Ibex RV32IMC core. Front-end flow: RTL → simulation → synthesized netlist.

**Legend:** ✅ done & verified  🚧 in progress  ⬜ not started

---

## Status at a glance

| Phase | Description | Status |
|-------|-------------|--------|
| A | Foundations & toolchain | ✅ |
| B | Architecture & design | 🚧 |
| C | RTL block development | 🚧 (2/12) |
| D | Integration | ⬜ |
| E | Synthesis → netlist | ⬜ |

---

## Phase A — Foundations & Toolchain ✅

| Item | Status |
|------|--------|
| SRAM macro characterization (ports, polarity, read latency) | ✅ |
| Toolchain verified (RISC-V GCC, Verilator, GTKWave) | ✅ |
| Ibex Simple System running `hello_test` in simulation | ✅ |
| Instruction trace verified against objdump | ✅ |
| riscv-tests ISA suite | ⬜ |

## Phase B — Architecture & Design 🚧

| Item | Status |
|------|--------|
| System block diagram | 🚧 |
| Memory map definition | ⬜ |
| Design hierarchy (synthesized vs. macro) | ⬜ |

## Phase C — RTL Block Development 🚧

| Block | Description | Verification | Status |
|-------|-------------|--------------|--------|
| `sram_bank_2k` | 2 KB bank (4× 512×8 macros, byte-lane writes) | 10 checks, 0 errors | ✅ |
| `mem_wrapper` | Ibex req/gnt/rvalid → SRAM interface | 5 reads, 0 errors | ✅ |
| `rst_sync` | Two-flop reset synchronizer | — | ⬜ |
| Memory subsystem | 2× bank + wrapper (instruction + data) | — | ⬜ |
| `ahb_bus` | AHB interconnect + address decoder | — | ⬜ |
| `ahb_apb_bridge` | AHB → APB bridge | — | ⬜ |
| `gpio` | 8-pin GPIO with input synchronizer | — | ⬜ |
| `uart` | UART TX/RX, configurable baud | — | ⬜ |
| `spi` | SPI controller + LCD driver | — | ⬜ |
| `scan_chain` | 248-cell scan chain (program load) | — | ⬜ |
| `clk_gen` | Ring-oscillator clock generator | — | ⬜ |
| `test_fsm` | Debug gating FSM | — | ⬜ |

## Phase D — Integration ⬜

| Milestone | Description | Status |
|-----------|-------------|--------|
| v0.1 | Memory subsystem + Ibex, `hello_test` passes | ⬜ |
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
| Process | GF180MCU (180nm) |
| Core area budget | 2051 × 2051 µm |

## Repository layout

```
ibex_soc/
├── rtl/    # synthesizable design (.sv)
├── tb/     # self-checking testbenches
└── README.md
```

## Running a testbench

```bash
iverilog -g2012 -o sim -s tb_sram_bank \
  tb/tb_sram_bank.sv rtl/sram_bank_2k.sv \
  /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram__sram512x8m8wm1.v
vvp sim
```
