# Area Report — RISC-V SoC on GF180MCU (180 nm)

**Target:** ≤ 1.0 mm² (1000 µm × 1000 µm die)
**Result:** **~0.85 mm² core (pads not counted) — FITS**

Logic area is from a real Yosys `synth → dfflibmap → abc → stat` run against the
GF180MCU standard-cell library (`gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib`).
SRAM macro areas come from the vendor datasheet. Ibex is pre-synthesized IP.
Pad area is estimated (final value depends on pad cells chosen at hardening).

## Summary

| Block | Area (µm²) | Area (mm²) | Method |
|---|---:|---:|---|
| Ibex RV32IMC core | 377,636 | 0.378 | Yosys (blackboxed here) |
| Custom SoC logic (chip_top_full) | 49,478 | 0.049 | Yosys (this run) |
| imem SRAM macro (512×8) | 209,000 | 0.209 | datasheet |
| dmem SRAM macro (512×8) | 209,000 | 0.209 | datasheet |
| **Core subtotal (no pads)** | **845,114** | **0.845** | |

| **TOTAL (core, pads excluded)** | **845,114** | **0.845** | **FITS 1 mm²** |

Margin to the 1 mm² limit: **~0.155 mm² (~15.5%)**. Pads are not counted in the area budget (per reviewer). Data memory was increased from 64 B to 512 B (still a single 8-bit macro) using the freed headroom.

## Custom logic contents

The 48,791 µm² of custom logic (up from 47,041 in the pre-Columbia design) includes
all the SoC glue: the two-tier AHB-Lite + APB bus, GPIO/UART/SPI peripherals,
narrow-memory gather/scatter wrappers, and the Columbia-style control infrastructure
added this phase — the 3-mode clock-gating FSM, the on-chip clock generator, and the
extended scan chain (which now writes FSM and clock-generator config registers, not
just memory). The +1,750 µm² increase over the previous design is these three blocks.

## Why the memory is "narrow"

A 32-bit-wide memory on GF180 requires **4 parallel 8-bit SRAM macros** per bank,
which pushes the chip over 1 mm² once the Ibex core and pads are included. Instead
this design uses **single 8-bit SRAM macros** with byte gather/scatter units:
- **Instruction memory:** one 512×8 macro + a byte-gather fetch unit that streams
  4 byte-reads and assembles each 32-bit instruction.
- **Data memory:** one 64×8 macro + a scatter/gather unit for 32-bit loads and
  byte-enabled stores, wrapped in an AHB-Lite slave with wait-states.

This trades a few extra cycles per memory access (irrelevant for the demo) for a
large area saving.

## Methodology note

Area is reported **per block, then summed** — the standard hierarchical-synthesis
practice for a design containing a CPU and hard macros. Ibex and the SRAM macros
are black-boxed (their areas taken from prior Ibex synthesis and the SRAM datasheet),
because Ibex ships simulation-only modules that are not synthesizable.

## Verification

The full SoC was simulated (Verilator, RTL) and gate-level simulated (iverilog on
`synthesis/chip_top.nl.v`) booting a real program: it scan-loads the program, scan-configures
the FSM to RUN, and drives **GPIO, UART = 0x41, SPI = 0xB7** — all correct in both
RTL and gate-level, confirming the netlist matches the RTL.
