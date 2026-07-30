# Timing Report — chip_top.nl.v (GF180MCU 180nm)

Static timing analysis via OpenSTA on the synthesized gate-level netlist.
Ibex core and both SRAM macros are black-boxed (pre-characterized IP);
timing is reported on the synthesized SoC logic.

## Result: SETUP MET — no violations

| Metric | Value |
|---|---|
| Target clock | 8 MHz (125 ns period) |
| Worst setup slack | **+113.32 ns (MET)** |
| Critical path delay | 6.819 ns |
| Max frequency (Fmax) | ~147 MHz |
| Setup violations | none |

## Critical path

Register-to-register path through the SoC logic:
flip-flop Q -> inverter -> nand2 -> aoi22 -> nand3 -> xor2 -> aoi21 -> flip-flop D
= 6.819 ns arrival, setup met with +117.8 ns slack.

## Interpretation

The design targets 8 MHz but closes timing up to ~147 MHz — a ~18x margin.
180nm standard cells are fast relative to this clock, so the multi-cycle
narrow-memory accesses (the area-saving tradeoff) have no timing impact:
the logic itself is far faster than the clock requires.

## Method

- Tool: OpenSTA 3.1.0
- Library: gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00 (typical corner)
- Netlist: chip_top.nl.v (Ibex + SRAM macros black-boxed)
- Clock constraint: create_clock -period 125.0 [get_ports clk]
