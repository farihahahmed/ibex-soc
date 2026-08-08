# Area Report — PicoRV32 SoC on GF180MCU (180 nm)

**Target:** 1000 µm × 1000 µm die (hard constraint)
**Result:** **PLACED AND ROUTED at exactly 1.0 mm² — signoff-clean**

## Final placed design (LibreLane/OpenROAD)

| Metric | Value |
|---|---:|
| Die area | 1,000,000 µm² (1000×1000) |
| Core area | 918,068 µm² |
| Placed instances | 46,344 |
| Utilization | 72.6% |
| Routed wirelength | ~718,000 µm |

## Synthesis breakdown (Yosys, gf180mcu_fd_sc_mcu7t5v0 tt)

| Block | Area (µm²) | Area (mm²) | Method |
|---|---:|---:|---|
| Whole-SoC logic (PicoRV32 + bus + peripherals + control) | 334,509 | 0.335 | Yosys stat |
| imem SRAM macro (256×8) | 147,213 | 0.147 | 431.86 × 340.88 µm |
| dmem SRAM macro (64×8) | 100,572 | 0.101 | 431.86 × 232.88 µm |

## Why PicoRV32 (the decisive change)

Ibex's only successfully hardened macro was 853×871 µm = **0.743 mm² for the
CPU alone**. Every re-harden at other aspect ratios failed placement, and
853 + 432 (SRAM width) = 1285 µm cannot tile into a 1000 µm die.

PicoRV32 (~40% smaller than Ibex in published comparisons, formally verified,
silicon-proven) is integrated as **synthesized RTL** — its gates place inline
with the peripherals and flow around the SRAMs. The entire SoC's logic
(0.335 mm²) is less than half of Ibex's macro alone, and there is no rigid
block to tile: the geometry problem disappears.

## Narrow memories

Each memory is a single 8-bit SRAM macro + byte gather/scatter (looks 32-bit
to the CPU). 256 B instruction / 64 B data — all three demo firmwares fit
(≤130 B code, stack low-water 0x14 within 64 B dmem).
