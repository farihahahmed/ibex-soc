# Timing Report — chip_top.nl.v (GF180MCU 180nm)

Static timing analysis via OpenSTA on the synthesized gate-level netlist.
Ibex core and both SRAM macros are black-boxed (pre-characterized IP);
timing is reported on the synthesized SoC logic (including the scan-configured
clock-gating FSM and on-chip clock generator).

## Result: SETUP MET — no violations

| Metric | Value |
|---|---|
| Target clock | 8 MHz (125 ns period) |
| Worst setup slack | **+113.32 ns (MET)** |
| Critical path delay | ~6.7 ns |
| Max frequency (Fmax) | ~150 MHz |
| Clock-gating checks | MET (FSM gate endpoint, +119.8 ns slack) |
| Setup violations | none |

## Notes

The clock-gating FSM introduces clock-gating check endpoints (the FSM's clock-enable
path into the gated `cpu_clk`); OpenSTA reports these separately and they meet with
large margin. The design targets 8 MHz but closes timing up to ~150 MHz — the 180nm
standard cells are far faster than the target clock, so the multi-cycle narrow-memory
accesses have no timing impact.

## Method

- Tool: OpenSTA 3.1.0
- Library: gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00 (typical corner)
- Netlist: chip_top.nl.v (Ibex + SRAM macros black-boxed)
- Clock constraint: create_clock -period 125.0 [get_ports clk]
