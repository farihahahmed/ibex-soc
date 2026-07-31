# Ibex SoC on GF180MCU

A RISC-V System-on-Chip on the open **GF180MCU (180 nm)** process, built around the Ibex RV32IMC core. Flow: RTL → simulation → synthesized netlist. The full SoC boots and drives all peripherals, verified in RTL and gate-level sim.

| | |
|---|---|
| **Die area** | ~0.82 mm² with pads — fits 1 mm² |
| **Pins** | 22 (20 signal + 2 power) |
| **Max frequency** | ~150 MHz (setup MET) |
| CPU | Ibex RV32IMC (small) |
| Memory | Narrow 8-bit: 512 B instr + 64 B data, byte gather/scatter |
| Bus | Two-tier AHB-Lite + APB |
| Peripherals | GPIO (2 in / 5 out), UART, SPI |
| Control/debug | Scan chain + 3-mode clock-gating FSM + on-chip clock generator (scan-configured) |

## Why it fits

**Narrow memory:** a 32-bit memory needs 4 SRAM macros per bank and won't fit 1 mm². Single 8-bit macros + byte gather/scatter units make them look 32-bit to the CPU. **Scan-configured control:** the scan chain loads the program and writes the FSM/clock-gen config registers, so control needs no dedicated pins.

## Layout

`rtl/` design · `tb/` testbenches · `chip_top.nl.v` netlist · `syn_netlist.ys` + `sta_timing.tcl` scripts · `older_version_of_design/` superseded modules

## Docs

[`AREA_REPORT`](AREA_REPORT.md) · [`TIMING_REPORT`](TIMING_REPORT.md) · [`PINOUT`](PINOUT.md) · [`memory_map`](memory_map.md) · [`progress_tracker`](progress_tracker.md) · [`detailed_schematic_review`](detailed_schematic_review.md)

## Verification

Every block has a self-checking testbench. The full SoC scan-loads a program, boots, and drives GPIO + UART (0x41) + SPI (0xB7) in both RTL (`tb/tb_chip_v2.sv`) and gate-level (`tb/tb_chip_gate_v2.sv`); OpenSTA reports setup MET (+113 ns).

```bash
iverilog -g2012 -o sim -s tb_test_fsm tb/tb_test_fsm.sv rtl/test_fsm.sv && vvp sim
```
