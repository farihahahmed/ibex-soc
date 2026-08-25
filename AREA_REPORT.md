# Area Report — PicoRV32 SoC on GF180MCU (180 nm)

**Slot:** A45, 1110 × 1110 µm available (per `A45_A.def`, organizer-confirmed).
**Implemented at:** 1100 × 1100 µm.
**Result:** placed and routed, signoff-clean.

Source: `openlane/chip_top_full/runs/RUN_2026-08-25_09-23-07/final/metrics.json` (tag `v2-signoff`).

## Final placed design (LibreLane / OpenROAD)

| Metric | Value |
|---|---:|
| Die area | 1,210,000 µm² (1100 × 1100) |
| Core area | 1,163,900 µm² (10 µm margin) |
| Standard-cell instances | 29,329 |
| Antenna diode cells | 10,751 |
| Macros | 2 |
| Total instances (incl. fill) | 65,989 |
| Standard-cell area | 471,081 µm² |
| Total instance area | 1,144,440 µm² |
| **Instance utilization** | **76.3%** |
| Standard-cell utilization | 63.2% |
| Routed wirelength | 992,388 µm |
| Total power (nom_tt) | 18.0 mW |

## Area breakdown

| Block | Area (µm²) | Notes |
|---|---:|---|
| Standard-cell logic (CPU + bus + peripherals + control + diodes) | 471,081 | placed cells |
| imem SRAM macro (512 × 8) | 209,404 | 431.86 × 484.88 µm |
| dmem SRAM macro (512 × 8) | 209,404 | 431.86 × 484.88 µm |
| Macro subtotal | 418,809 | 2 × `gf180mcu_fd_ip_sram__sram512x8m8wm1` |

Macros are placed at `[120, 300]` and `[560, 300]`, orientation N.

## Narrow memories

Each memory is a single 8-bit SRAM macro fronted by a byte gather/scatter unit,
so it presents as a normal 32-bit memory to the CPU. A conventional 32-bit
memory would need four macros per bank; this design uses one.

Capacity is **512 B instruction + 512 B data = 1 KB total**. All three demo
firmwares fit comfortably (largest is 172 B).

## Why PicoRV32 (design history)

Ibex's only successfully hardened macro was 853 × 871 µm = **0.743 mm² for the
CPU alone**. Every re-harden at other aspect ratios failed placement, and
853 + 432 µm (SRAM width) cannot tile into a 1000 µm die.

PicoRV32 is integrated as **synthesized RTL** rather than a hard macro, so its
gates place inline with the peripherals and flow around the SRAMs. There is no
rigid block to tile, and the geometry problem disappears.

## Area history

| Version | Memory | Die | Utilization |
|---|---|---|---:|
| v1 signoff | 320 B (256 + 64) | 1000 × 1000 | 77.8% |
| **v2 signoff** | **1 KB (512 + 512)** | **1100 × 1100** | **76.3%** |

The die grew because the A45 slot allows 1110 × 1110; the original 1000 × 1000
was a self-imposed conservative choice, not a given constraint. Reclaiming that
area is what allowed memory to triple while keeping the full RV32E+M+C core.
