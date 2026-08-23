# Gate-level smoke

**Status:** READY / PASS

## Netlist
Pico-era final:
openlane/chip_top_full/runs/RUN_2026-08-08_06-31-45/final/nl/chip_top_full.nl.v

(Not the older Ibex-era RUN_2026-08-06_08-51-08 netlist.)

## How to run
cd verification/gl && make gl-smoke

Expected: GL SMOKE PASS and exit 0.

## What it proves
- Post-PnR netlist + GF180 cells + SRAM models
- Reset/clocks/top ports alive

## Not yet
- Full FW on GL
- Formal GL vs RTL compare
