# PicoRV32 SoC on GF180MCU — 1 mm², signoff-clean

A RISC-V System-on-Chip on the open **GF180MCU (180 nm)** process, built around
the **PicoRV32** core (RV32IMC). Full flow: **RTL → simulation → synthesis →
place-and-route → signoff-clean GDS**, entirely with open-source tools
(Icarus, Yosys, LibreLane/OpenROAD, Magic, Netgen).

> Repo name note: the project began with the Ibex core ("ibex-soc"); Ibex's
> hardened macro (0.743 mm²) could not tile with the SRAMs inside the 1 mm²
> die, so the CPU was swapped for PicoRV32, which synthesizes inline with the
> logic. The name is historical.

## Final signoff (healed GDS: `gds/chip_top_full_healed.gds`)

| Check | Result |
|---|---|
| **DRC** | **0 errors** (Magic full check) |
| **LVS** | **Circuits match uniquely** (13,966 devices / 13,021 nets) |
| **Antenna** | **Passed** (0 violations) |
| **Setup timing** | Clean, all 9 corners (worst +78.1 ns @ ss_125C_4v50) |
| **Hold timing** | Clean, all 9 corners (worst +0.283 ns @ ff_n40C_5v50) |
| **Die** | **1000 µm × 1000 µm = 1.0 mm² (hard constraint, met)** |
| Utilization | 72.6% placed (46,344 instances) |

| | |
|---|---|
| CPU | PicoRV32 RV32IMC (MUL/DIV on, IRQ off), synthesized as std cells |
| Memory | Narrow 8-bit: 256 B instr + 64 B data, byte gather/scatter |
| Bus | Two-tier AHB-Lite + APB |
| Peripherals | GPIO (2 in / 5 out), UART, SPI |
| Control | Scan chain + 3-mode clock-gating FSM + on-chip clock gen |
| Clock | 10 MHz target (100 ns), external clk → ÷2 → gated cpu_clk |
| Pins | 22 (20 signal + 2 power) |

## Two key design decisions

**1. Narrow memory:** a 32-bit memory needs 4 SRAM macros per bank. Single
8-bit macros + byte gather/scatter units make them look 32-bit to the CPU.

**2. PicoRV32 as inline RTL, not a macro:** Ibex only hardened as a rigid
853×871 µm block that could not tile with the 432 µm-wide SRAMs in 1000 µm.
PicoRV32 (~40% smaller in literature) is handed to LibreLane as RTL, so its
gates flow around the SRAM macros — the tiling problem disappears. Whole-SoC
logic: 0.335 mm² synthesized.

## The Metal3 heal (known GF180 SRAM/PDN issue)

The PDN's Metal3 connection to the GF180 SRAM macros leaves 4 sub-micron
slivers (Metal3 width < 0.56 µm) — a documented tool issue
(OpenLane #1549 / OpenROAD PR #2814; the upstream fix reduces but does not
eliminate it for these macros). Fix: `gds/heal_metal3.tcl` widens the 4
shapes to legal width in Magic post-P&R. The healed GDS then passes **full DRC
(0 errors)** and **LVS (match)** — both re-verified on the healed file.

Workflow: `librelane config.json` → run heal script → re-verify DRC + LVS.

## Layout

`rtl/` design incl. `picorv32.v` CPU ·
`tb/` self-checking testbenches + firmware .svh · `firmware/` 3 demo programs ·
`openlane/chip_top_full/` flow config (config.json, SDC, PDN, SRAM macros) ·
`gds/` healed GDS + heal script + signoff reports ·
`synthesis/` SRAM blackbox stubs (flow inputs) · `older_version_of_design/` superseded modules

## Verification

Every block has a self-checking testbench (18 pass). The full SoC scan-loads a
program, boots PicoRV32, and drives GPIO + UART (0x41) + SPI (0xB7)
(`tb/tb_chip_v2.sv`). All three real firmwares verified on the CPU:

- **primes** — UART prints `2 3 5 7 11 13 17 19 23 29 31 37 41 43 47` (MUL/MOD exercised)
- **piezo_tune** — GPIO square-wave tone (1018 toggles)
- **game** — SPI/LCD drive (15,376 SCLK toggles)
## Docs

[`AREA_REPORT`](AREA_REPORT.md) · [`TIMING_REPORT`](TIMING_REPORT.md) ·
[`PINOUT`](PINOUT.md) · [`memory_map`](memory_map.md) ·
[`progress_tracker`](progress_tracker.md)
