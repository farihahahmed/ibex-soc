# Ibex SoC on GF180MCU

A from-scratch RISC-V System-on-Chip on the open-source **GF180MCU (180 nm)** process, built around the Ibex RV32IMC core. Flow: RTL → simulation → synthesized gate-level netlist.

The full SoC boots via a scan-configured clock-gating FSM, runs a program from on-chip memory, and drives all peripherals — verified in both RTL and gate-level simulation. It fits the target die and pin budget:

| | |
|---|---|
| **Die area** | ~0.82 mm² with pads (0.74 mm² core) — fits 1 mm² |
| **Pins** | 22 total (20 signal + 2 power) |
| **Max frequency** | ~150 MHz (setup MET) |

## Architecture

| | |
|---|---|
| CPU | Ibex RV32IMC (small config) |
| Memory | Narrow 8-bit: 512 B instruction (1× 512×8) + 64 B data (1× 64×8), byte gather/scatter |
| Bus | Two-tier AHB-Lite + APB |
| Peripherals | GPIO (2 in / 5 out), UART, SPI |
| Control / debug | Scan chain + 3-mode clock-gating FSM + on-chip clock generator, all scan-configured |
| Process | GF180MCU (180 nm) |

Two design levers make it fit:

1. **Narrow memory.** A 32-bit memory needs four 8-bit SRAM macros per bank and won't fit 1 mm². Instead, single 8-bit macros are fronted by byte gather/scatter units that make them look like normal 32-bit memory to the CPU (reads stream 4 bytes and assemble a word; writes split into byte-enabled byte-writes). The data memory adds AHB wait-states for its multi-cycle access.

2. **Scan-configured control.** The chip is initialized and debugged entirely through the scan chain — no dedicated control pins. The scan chain loads the program *and* writes the FSM and clock-generator config registers. The FSM has three modes: idle (clock suppressed during scan), running (clock passes), and countdown (run N cycles then gate, for cycle-accurate debug). The clock generator provides a scan-programmable divided clock with external-clock fallback.

## Repository layout

| Path | Contents |
|------|----------|
| `rtl/` | Synthesizable design (SystemVerilog) |
| `tb/` | Self-checking testbenches |
| `chip_top.nl.v` | Deliverable gate-level netlist |
| `syn_netlist.ys` | Yosys synthesis script |
| `sta_timing.tcl` | OpenSTA timing script |
| `older_version_of_design/` | Superseded modules, kept for reference |
| `diagrams/` | Block diagrams and figures |

## Documentation

| File | Contents |
|------|----------|
| [`AREA_REPORT.md`](AREA_REPORT.md) | Area breakdown (~0.82 mm², fits 1 mm²) |
| [`TIMING_REPORT.md`](TIMING_REPORT.md) | Static timing (setup MET, ~150 MHz) |
| [`PINOUT.md`](PINOUT.md) | 22-pin list with types |
| [`memory_map.md`](memory_map.md) | Address map + narrow-memory notes |
| [`progress_tracker.md`](progress_tracker.md) | Block-by-block status |
| [`detailed_schematic_review.md`](detailed_schematic_review.md) | Design walkthrough |

## Verification

- **Block level** — every block (FSM, clock generator, scan chain, GPIO, narrow memories, bus, peripherals) has a self-checking testbench.
- **RTL** — the full SoC scan-loads a program, scan-configures the FSM to RUN, boots, and drives GPIO + UART (0x41) + SPI (0xB7). See `tb/tb_chip_v2.sv`.
- **Gate level** — the synthesized netlist reproduces the same outputs, confirming RTL-vs-netlist equivalence. See `tb/tb_chip_gate_v2.sv`.
- **Timing** — OpenSTA reports setup MET, +113 ns worst-case slack.

## Running a testbench

```bash
# a single block
iverilog -g2012 -o sim -s tb_test_fsm tb/tb_test_fsm.sv rtl/test_fsm.sv && vvp sim
```

Full-SoC and gate-level testbenches build with Verilator / iverilog against the Ibex source list.
