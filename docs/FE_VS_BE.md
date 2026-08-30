# Front-End vs Back-End — chip_top_full

A like-for-like comparison of the **pre-layout synthesis estimate** (Yosys
0.64 + OpenSTA, ideal wires) against the **post-route signoff** (LibreLane /
OpenROAD, real parasitics), both on the same ICG RTL.

- Front-end source: `fe_report/` (`synth_area.ys`, `fe_timing.tcl`)
- Back-end source: `openlane/chip_top_full/runs/RUN_2026-08-29_12-40-30/final/metrics.json`

Front-end and back-end measure different things on purpose: the front end tells
you whether the **logic** fits and closes; the back end tells you what the
**silicon** actually does after placement, clock-tree synthesis, routing,
antenna repair, and fill. The table below gives the exact number for each, and
why it differs.

## Area

| Metric | Front-end (synthesis) | Back-end (signoff) | Why it differs |
| --- | ---: | ---: | --- |
| Std-cell logic area | 397,658 µm² | — | FE is logic only; BE reports placed area instead (next rows) |
| Sequential-cell area | 160,704 µm² | 162,904 µm² | +1.3% — resizer up-sized some flops; near-identical |
| Instance (placed) area | — | 1,163,850 µm² | BE includes buffers, diodes, fill, and both SRAM macros |
| Die area | — | 1,232,100 µm² (1110×1110) | Fixed floorplan; not a synthesis output |
| Core utilization | — | 80.5% | Placed cell area / core area; no FE equivalent |
| SRAM macros | 2 × 209,404 µm² (from LEF) | 2 × 209,404 µm² | Identical — hardened macro, unchanged by either flow |

Sequential area matches within 1.3% front to back — the datapath the synthesis
predicted is the datapath that was built.

## Instance counts

| Metric | Front-end | Back-end | Why it differs |
| --- | ---: | ---: | --- |
| Std cells (functional) | 14,483 | 32,140 | +17,657 — see breakdown below |
| Fill cells | 0 | 39,534 | Fill is a back-end-only step (fills empty core area; non-functional) |
| Total instances | 14,483 | 71,676 | Functional + fill + macros |
| Flip-flops | 2,445 | 2,477 | +32 — CTS/resizer added a few clock-domain registers |
| Integrated clock gates | 3 | 3 | Identical — the cpu_clk / clk_gen ICGs survive unchanged |

**Where the +17,657 back-end cells come from** (all post-synthesis physical
steps the front end cannot model):

| Added cell class | Count | Purpose |
| --- | ---: | --- |
| Antenna diodes | 10,641 | Protect gates from charge during etch (antenna repair) |
| Timing-repair buffers | 781 | Fix setup/transition on real routed nets |
| Hold buffers | 265 | Add delay to meet hold with real clock skew |
| CTS + resizer + taps | ~5,876 | Clock-tree buffers, driver up-sizing, well taps |

None of these exist at synthesis: they are added by placement, CTS, routing, and
antenna repair. This is the expected, healthy shape of an FE→BE transition — the
functional logic is stable, and the growth is physical infrastructure.

## Timing

| Metric | Front-end (ideal clocks) | Back-end (post-route, 9 corners) | Why it differs |
| --- | ---: | ---: | --- |
| Target period | 40 ns (25 MHz) | 40 ns (25 MHz) | Same constraint |
| Setup worst slack | +0.203 ns | +4.17 ns | BE is *better*: resizer buffered the fanout the FE left unsized |
| Setup violations | 0 | 0 | Meets at both stages |
| Hold worst slack | −70.96 ns (see note) | +0.33 ns | FE hold is meaningless pre-CTS; BE hold is real and met |
| Hold violations | n/a (no clock tree) | 0 | — |
| Worst-path logic depth | 4 gates | — | Shallow logic; BE reports slack, not depth |

**On the two timing numbers that look alarming in the front-end column:**

- **Setup +0.203 ns looks tight, but it is pessimistic.** The pre-layout worst
  path is only four gates deep, yet a single 1× inverter on it takes 18.5 ns
  because synthesis has not sized that driver for its fanout. Once the back-end
  resizer buffers those nets, the same design closes with **+4.17 ns** at the
  worst PVT corner. The front-end number is a floor, not the final margin.

- **Hold −70.96 ns is an artifact, not a violation.** With no clock tree yet,
  OpenSTA propagates an invented ~82.9 ns clock-network delay to the capture
  flop, producing a nonsense negative hold slack. Hold depends entirely on the
  real clock tree, which does not exist until CTS — so pre-layout hold is
  meaningless *by construction*. The back-end, with the real tree, measures
  **+0.33 ns hold, met on all 9 corners**. We show the −70.96 ns figure rather
  than hiding it, to be explicit about why front-end hold is not evaluated.

## Frequency (fmax, back-end, worst corner ss_125C_4v50)

| Clock domain | fmax | Operating | Margin |
| --- | ---: | ---: | ---: |
| `clk` (input) | 112 MHz | 25 MHz | 4.5× |
| `sys_clk` | 31 MHz | 12.5 MHz | 2.5× |
| `cpu_clk` (CPU) | 13.2 MHz | 12.5 MHz | ~5% |

fmax is a back-end result (needs real parasitics); the front end only confirms
the logic closes at the target period. The CPU domain is the binding one.

## Signoff-only checks (no front-end equivalent)

| Check | Back-end result |
| --- | --- |
| Antenna violations | 0 |
| LVS | Clean (0 errors) |
| DRC | 4 — all in the GF180 SRAM macro, waived |
| IR drop (worst) | 2.05 mV (0.04%) |
| Routed wirelength | 1,285,066 µm |
| Vias | 143,484 (single-cut) |
| Power (nom_tt) | 48.1 mW |
| Max-slew / max-cap | 5,020 / 235 — advisory, non-gating, timing met |

## In summary

Synthesis predicted the design accurately: **sequential area within 1.3%**,
**flop count within 32**, **ICG count exact**, and **timing closing at the
target period**. The back end adds physical infrastructure (10,641 diodes, ~5.9k
CTS/resizer cells, 39.5k fill) and, with real parasitics, *improves* setup slack
from a pessimistic +0.20 ns to a comfortable +4.17 ns while meeting hold on all
nine PVT corners. Front-end feasibility held all the way through signoff.
