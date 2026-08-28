# Timing Report — chip_top_full, placed & routed (GF180MCU 180 nm)

STA on the **final placed-and-routed design** (LibreLane / OpenSTA), all 9 PVT
corners (process min/nom/max × ff_n40C_5v50 / tt_025C_5v00 / ss_125C_4v50).

Source: `openlane/chip_top_full/runs/RUN_2026-08-25_09-23-07` (tag `v2-signoff`).

## Result: ALL CORNERS CLEAN

| Check | Worst slack | Worst corner | Verdict |
|---|---:|---|---|
| Setup | **+10.010 ns** | max_ss_125C_4v50 | MET (all 9) |
| Hold | **+0.087 ns** | max_ff_n40C_5v50 | MET (all 9) |

**Target clock: 32 ns (31.25 MHz)** on external `clk`. Generated clocks
`sys_clk` (÷2) and `cpu_clk` (gated) are declared in
`openlane/chip_top_full/chip_top.sdc` with `set_propagated_clock`.

## Per-corner setup slack (ns)

| Corner | min | nom | max |
|---|---:|---:|---:|
| ff_n40C_5v50 | 26.749 | 26.531 | 26.275 |
| tt_025C_5v00 | 23.821 | 23.497 | 23.115 |
| ss_125C_4v50 | 15.254 | 12.890 | **10.010** |

## Per-corner hold slack (ns)

| Corner | min | nom | max |
|---|---:|---:|---:|
| ff_n40C_5v50 | 0.243 | 0.169 | **0.087** |
| tt_025C_5v00 | 0.503 | 0.487 | 0.470 |
| ss_125C_4v50 | 0.976 | 0.946 | 0.914 |

Hold margin is thin on the fast corner (+0.087 ns) but positive on all nine.
Hold-fix buffering is bounded (`*_HOLD_SLACK_MARGIN = 0.2`,
`*_HOLD_MAX_BUFFER_PCT = 30`); unbounded insertion overflows detailed placement
at this density.

## Frequency

31 MHz is the shipped frequency. The binding constraint historically was
antenna rather than setup: a shorter period requires more timing buffers, and
the added routing has reintroduced antenna violations in past attempts.

| Clock | Setup WNS | Antenna | Verdict |
|---|---:|---|---|
| 100 ns (10 MHz) | +83.4 ns | 0 | clean |
| 40 ns (25 MHz) | +19.2 ns | 0 | clean |
| **32 ns (31 MHz)** | **+10.010 ns** | **0** | **shipped** |
| 30 ns (33 MHz) | +0.015 ns | 1 | rejected (earlier config) |

The 30 ns result above predates the current hold-margin settings, under which
setup margin at 32 ns improved from +3.17 ns to +10.01 ns. A faster clock may
now be reachable; this has not been re-tested and is noted as future work.

## Notes

- Max-slew and max-cap checkers print per-corner warnings that resolve to
  "No violations found" — reporting noise, not failures.
- `cpu_clk` has a fanout of 2,165 terminals. Functional, but unusual;
  restructuring the clock tree in RTL is noted as future work.
