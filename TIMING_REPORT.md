# Timing Report — chip_top_full, placed & routed (GF180MCU 180 nm)

STA on the **final placed-and-routed design** (LibreLane/OpenSTA), all 9
PVT corners (process min/nom/max × ff_n40C_5v50 / tt_025C_5v00 / ss_125C_4v50).

## Result: ALL CORNERS CLEAN

| Check | Worst slack | Worst corner | Verdict |
|---|---:|---|---|
| Setup | **+75.07 ns** | max_ss_125C_4v50 | MET (all 9) |
| Hold | **+0.328 ns** | min_ff_n40C_5v50 | MET (all 9) |

Target clock: 10 MHz (100 ns) on external `clk`; generated clocks `sys_clk`
(÷2) and `cpu_clk` (gated) declared in `openlane/chip_top_full/chip_top.sdc`
with `set_propagated_clock`.

## Per-corner setup slack (ns)

| Corner | min | nom | max |
|---|---:|---:|---:|
| ff_n40C_5v50 | 92.23 | 91.76 | 91.20 |
| tt_025C_5v00 | 87.81 | 87.07 | 86.19 |
| ss_125C_4v50 | 77.91 | 76.60 | 75.07 |

## Per-corner hold slack (ns)

| Corner | min | nom | max |
|---|---:|---:|---:|
| ff_n40C_5v50 | 0.328 | 0.329 | 0.332 |
| tt_025C_5v00 | 0.537 | 0.539 | 0.542 |
| ss_125C_4v50 | 1.018 | 1.019 | 1.022 |

## Notes

- Hold margins are intentionally lean: hold-fix buffering was capped
  (HOLD_MAX_BUFFER_PCT=20, margin 0.1 ns) because unbounded buffer insertion
  (3055 buffers, 165k µm²) overflowed detailed placement at this density.
  All corners remain positive.
- Max-slew/max-cap checker warnings appear per-corner but resolve to
  "No violations found" — reporting noise, not failures.
