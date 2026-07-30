# Area Report — RISC-V SoC on GF180MCU (180 nm)

**Target:** ≤ 1.0 mm² (1000 µm × 1000 µm die)
**Result:** **0.911 mm² — FITS with 8.9% margin**

All logic areas below were produced by real Yosys `synth → dfflibmap → abc → stat`
runs against the GF180MCU standard-cell library
(`gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib`). SRAM macro areas come from the
vendor LEF (physical dimensions). Pads are estimated.

## Summary

| Block | Area (µm²) | Area (mm²) | Method |
|---|---:|---:|---|
| Ibex RV32IMC core | 377,636 | 0.378 | Yosys (slang frontend) |
| Custom SoC logic | 31,857 | 0.032 | Yosys |
| imem narrow logic (byte-gather fetch) | 15,204 | 0.015 | Yosys |
| dmem narrow logic (byte scatter/gather + AHB wait-state) | 26,720 | 0.027 | Yosys |
| imem SRAM macro (512×8) | 209,000 | 0.209 | datasheet LEF |
| dmem SRAM macro (64×8) | 101,000 | 0.101 | datasheet LEF |
| I/O pads (~20) | 150,000 | 0.150 | estimate |
| **TOTAL** | **911,417** | **0.911** | **FITS 1 mm²** |

Margin to the 1 mm² limit: **0.089 mm² (8.9%)**.

## Custom SoC logic breakdown (Yosys-printed)

| Module | Area (µm²) |
|---|---:|
| uart | 7,365 |
| ahb_to_apb | 7,060 |
| scan_chain | 5,705 |
| spi | 4,175 |
| ahb_interconnect | 2,634 |
| gpio | 2,031 |
| apb_decoder | 1,932 |
| test_fsm | 261 |
| ahb_gpio | 213 |
| ibex_to_ahb | 213 |
| rst_sync | 149 |
| apb_spi | 40 |
| apb_uart | 40 |
| apb_gpio | 40 |
| **Subtotal** | **31,857** |

## Why the memory is "narrow"

A 32-bit-wide memory on GF180 requires **4 parallel 8-bit SRAM macros** per bank.
Even the smallest 32-bit configuration (4 × 64×8 = 0.404 mm²) pushes the chip over
1 mm² once the Ibex core (0.378) and pads are included. **A conventional 32-bit
memory cannot fit the 1 mm² die.**

The fix: use **single 8-bit SRAM macros** with byte gather/scatter units.
- **Instruction memory:** one 512×8 macro + a byte-gather fetch unit that streams
  4 consecutive byte-reads and assembles each 32-bit instruction.
- **Data memory:** one 64×8 macro + a scatter/gather unit that handles 32-bit
  loads (4 byte-reads) and byte-enabled stores (1–4 byte-writes), wrapped in an
  AHB-Lite slave with wait-states (it stalls the bus during the multi-cycle access).

This trades a few extra cycles per memory access (irrelevant for the demo) for a
large area saving: the data memory drops from ~0.84 mm² (old 2 KB, 4-macro) to
~0.13 mm² (macro + logic).

## Methodology note

Area is reported **per block, then summed** — the standard hierarchical-synthesis
practice for any design containing a CPU and hard macros. A single flat whole-chip
synthesis is not used because Ibex ships simulation-only modules (instruction
tracer, DPI memory-load tasks, I/O pad models) that are not synthesizable and are
excluded from a real synthesis file-list. Each block above was synthesized and its
`Chip area` line printed by Yosys.

## Verification

This is not just an area estimate — the full SoC was simulated (Verilator) booting
a real program from **both** narrow memories:
- Ibex fetches every instruction through the byte-gather unit from the 512×8 imem.
- The CPU's data accesses go over the AHB bus to the narrow data memory.
- The program drives all peripherals: **GPIO = 0xA5, UART = 0x41, SPI = 0xB7** —
  all correct.

Both narrow memories were independently verified (read/write/byte-enable
testbenches) before integration, and the full chip boots and executes correctly.
