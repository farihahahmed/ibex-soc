# Timing Report — chip_top_full, placed & routed (GF180MCU 180 nm)

STA on the **final placed-and-routed design** (LibreLane/OpenSTA), all 9
PVT corners (process min/nom/max × ff_n40C_5v50 / tt_025C_5v00 / ss_125C_4v50).

## Result: ALL CORNERS CLEAN

| Check | Worst slack | Worst corner | Verdict |
|---|---:|---|---|
| Setup | **+78.08 ns** | max_ss_125C_4v50 | MET (all 9) |
| Hold | **+0.283 ns** | min_ff_n40C_5v50 | MET (all 9) |

Target clock: 10 MHz (100 ns) on external `clk`; generated clocks `sys_clk`
(÷2) and `cpu_clk` (gated) declared in `openlane/chip_top_full/chip_top.sdc`
with `set_propagated_clock`.

## Per-corner setup slack (ns)

| Corner | min | nom | max |
|---|---:|---:|---:|
| ff_n40C_5v50 | 93.10 | 92.73 | 92.29 |
| tt_025C_5v00 | 89.16 | 88.57 | 87.89 |
| ss_125C_4v50 | 80.32 | 79.28 | 78.08 |

## Per-corner hold slack (ns)

| Corner | min | nom | max |
|---|---:|---:|---:|
| ff_n40C_5v50 | 0.283 | 0.315 | 0.327 |
| tt_025C_5v00 | 0.535 | 0.537 | 0.540 |
| ss_125C_4v50 | 1.020 | 1.023 | 1.026 |

## Notes

- Hold margins are intentionally lean: hold-fix buffering was capped
  (HOLD_MAX_BUFFER_PCT=20, margin 0.1 ns) because unbounded buffer insertion
  (3055 buffers, 165k µm²) overflowed detailed placement at this density.
  All corners remain positive.
- Max-slew/max-cap checker warnings appear per-corner but resolve to
  "No violations found" — reporting noise, not failures.
