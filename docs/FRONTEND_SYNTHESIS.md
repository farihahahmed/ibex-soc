# Front-End Synthesis & Feasibility — chip_top_full

Pre-layout synthesis of the full SoC with **Yosys 0.64** (area) and **OpenSTA**
(timing), mapped to the GF180MCU `gf180mcu_fd_sc_mcu7t5v0` standard-cell library
(tt, 25 °C, 5.0 V). These are **pre-layout estimates** — logic only, before
placement, clock-tree synthesis, and routing. They confirm the design fits and
closes timing ahead of the back-end flow.

Reproduce: `fe_report/synth_area.ys` (area) and `fe_report/fe_timing.tcl`
(timing).

## Area (Yosys, post-synthesis)

| Metric | Value |
| --- | ---: |
| Standard-cell logic area | **397,658 µm² (0.398 mm²)** |
| — sequential (flops + ICG) | 160,704 µm² (40.4%) |
| — combinational | 236,954 µm² (59.6%) |
| Standard cells | 14,483 |
| Flip-flops | 2,445 (`dffq` 1,989 · `dffrnq` 445 · `dffsnq` 11) |
| Integrated clock gates (`icgtp_1`) | 3 |
| SRAM macros | 2 × `sram512x8` = 418,809 µm² (0.419 mm²) |
| **Logic + macros** | **~816,000 µm² (0.816 mm²)** |

Yosys reports std-cell logic area only; SRAM macro area is added from the macro
LEF (Yosys black-boxes hardened macros). This is post-synthesis logic area — it
stays roughly stable through placement; the back-end adds clock-tree, buffering,
and fill on top (final signoff utilization 82 % in a 1.21 mm² die).

Largest area consumers: `dffq` flops (127k µm²), `mux2` (52k), `dffrnq` (33k),
`nand2` (27k) — flop-dominated, as expected for a CPU SoC with a CRC/MAC
datapath.

## Timing (OpenSTA, ideal clocks)

Synthesized netlist, primary clock constrained at 40 ns, ideal clock network
(no CTS or wire delay yet).

| Metric | Value |
| --- | ---: |
| Target period | 40 ns (25 MHz) |
| Worst setup slack | **+0.203 ns (MET)** |
| Critical-path arrival | 39.494 ns |
| Logic depth on worst path | 4 levels (`clkinv → nor2 → nor2 → mux2`) |

**Reading this number honestly:** the worst path is only four gates deep, but a
single 1× inverter on it takes 18.5 ns because pre-layout synthesis has not yet
sized drivers for their fanout. The slack is therefore *pessimistic* — it is
drive-limited, not logic-limited. The back-end resizer buffers these nets, and
post-route signoff timing improves to **+4.17 ns worst-corner setup, +0.33 ns
hold, clean across all 9 PVT corners** (see the back-end signoff report). The
front-end result confirms the logic is shallow and closes at the target period;
final margin is set at signoff.

## Conclusion

Synthesis confirms the design: **0.4 mm² of standard-cell logic plus 0.42 mm²
of SRAM (0.82 mm² total)**, **22 pins (20 signal + 2 power)**, timing closing at
the **25 MHz** target. Size and frequency are decided and validated in
synthesis; full place-and-route signoff confirms them (antenna 0, LVS clean,
timing met on all 9 corners).
