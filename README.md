# Ibex SoC on GF180MCU

A from-scratch RISC-V System-on-Chip built on the open-source **GF180MCU (180nm)** process, using the Ibex RV32IMC core. Front-end flow: RTL → simulation → synthesized netlist.

**Status: complete front-end flow.** The full SoC boots via a scan-configured clock-gating FSM, runs a program from on-chip memory, and drives all peripherals — verified in both RTL and gate-level simulation. It synthesizes to **~0.82 mm²** (0.74 mm² core), fitting the 1 mm² die target, with **22 pins** (20 signal + 2 power).

## Contents

| Path | What's inside |
|------|---------------|
| [`progress_tracker.md`](progress_tracker.md) | Live status of every block, phase by phase |
| [`AREA_REPORT.md`](AREA_REPORT.md) | Synthesized area breakdown (~0.82 mm², fits 1 mm²) |
| [`TIMING_REPORT.md`](TIMING_REPORT.md) | Static timing: setup MET, ~150 MHz Fmax |
| [`PINOUT.md`](PINOUT.md) | 22-pin list (20 signal + 2 power) |
| [`memory_map.md`](memory_map.md) | Address map + narrow-memory notes |
| `chip_top.nl.v` | Deliverable gate-level netlist |
| `rtl/` | Synthesizable design files (`.sv`) |
| `tb/` | Self-checking testbenches |

## Quick specs

| | |
|---|---|
| CPU | Ibex RV32IMC (small config) |
| Memory | Narrow 8-bit: 512 B instruction (1× 512×8) + 64 B data (1× 64×8), byte gather/scatter |
| Peripherals | GPIO (2 in / 5 out), UART, SPI |
| Bus | Two-tier AHB-Lite + APB |
| Control/debug | Scan chain + 3-mode clock-gating FSM + on-chip clock generator (all scan-configured) |
| Process | GF180MCU (180nm) |
| Die area | ~0.82 mm² with pads / 0.74 mm² core — fits 1 mm² |
| Pins | 22 total (20 signal + 2 power) |
| Max frequency | ~150 MHz (setup MET at target clock) |

## Key results

**Fits 1 mm² via narrow memory.** A conventional 32-bit memory needs four 8-bit SRAM macros per bank and does not fit. This design uses single 8-bit SRAM macros fronted by byte gather/scatter units that make them look like normal 32-bit memory to the CPU. See [`AREA_REPORT.md`](AREA_REPORT.md).

**Columbia-style control infrastructure.** The chip is initialized and debugged entirely through the scan chain (no dedicated control pins): the scan chain loads the program and writes the FSM and clock-generator config registers. The FSM has three modes — idle (clock suppressed during scan), running (clock passes), and countdown (run N cycles then gate, for cycle-accurate debug). An on-chip clock generator provides a scan-programmable divided clock with external-clock fallback.

## Verification

- **Block level:** every block (FSM, clock generator, scan chain, GPIO, narrow memories, peripherals) has a self-checking testbench.
- **RTL simulation:** the full SoC scan-loads a program, scan-configures the FSM to RUN, boots, and drives GPIO + UART (0x41) + SPI (0xB7).
- **Gate-level simulation:** the synthesized netlist (`chip_top.nl.v`) reproduces the same peripheral outputs — RTL-vs-netlist equivalence confirmed.
- **Timing:** OpenSTA reports setup MET with +113 ns worst-case slack.

## Running a testbench

```bash
iverilog -g2012 -o sim -s tb_test_fsm tb/tb_test_fsm.sv rtl/test_fsm.sv
vvp sim
```

Full-SoC integration and gate-level testbenches build with Verilator / iverilog against the Ibex source list; see `tb/tb_chip_v2.sv` (RTL) and `tb/tb_chip_gate_v2.sv` (gate-level).
