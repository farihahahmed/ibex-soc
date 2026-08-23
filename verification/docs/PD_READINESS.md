# PD + silicon readiness (B4)

## Timing — MET
Source: `TIMING_REPORT.md` (LibreLane / OpenSTA, final P&R).

| Check | Worst slack | Verdict |
|-------|------------:|---------|
| Setup | +75.07 ns (ss_125C_4v50 max) | MET all 9 corners |
| Hold  | +0.328 ns (ff_n40C_5v50 min) | MET all 9 corners |

Target: 10 MHz external `clk`. Hold intentionally lean (buffer cap); all positive.

## Pinout — documented
Source: `PINOUT.md`  
22 pins (20 signal + VDD/VSS). Matches top-level ports used by RTL + scan/GPIO/UART/SPI demos.

## LVS / DRC
OpenLane run: `RUN_2026-08-06_08-51-08`  
Artifacts present under:
- `70-netgen-lvs/`
- `64-magic-drc/`
- `66-checker-magicdrc/`, `67-checker-klayoutdrc/`, `71-checker-lvs/`

**Action before freeze:** paste final checker PASS/FAIL lines into this section
(or attach `lvs.netgen.rpt` / DRC rpt tails). Do not claim clean without those lines.

## Gate-level vs RTL
Current GL status: **SKIP** (`verification/docs/GATE_LEVEL.md`).  
Reason: last netlist still contains `ibex_top` (Ibex-era); DUT is PicoRV32.

**To close B4 fully:**
1. Re-run LibreLane on current Pico RTL  
2. `make gl-smoke` PASS  
3. Optional: same directed smoke on RTL + GL, compare GPIO/UART

## B4 scorecard
| Item | Status |
|------|--------|
| Timing closed + report in repo | **DONE** |
| Pinout matches demos | **DONE** |
| LVS/DRC evidence in run dir | **PRESENT** — confirm PASS text |
| GL vs RTL compare | **OPEN** (needs Pico netlist) |
