# PicoRV32 SoC on GF180MCU — Progress Tracker

Full flow: RTL → simulation → synthesis → place-and-route → **signoff-clean GDS**.

**Legend:** ✅ done & verified  🚧 in progress  ⬜ not started

---

## Status at a glance

| Phase | Description | Status |
|-------|-------------|--------|
| A | Foundations & toolchain | ✅ |
| B | Architecture & design | ✅ |
| C | RTL block development | ✅ |
| D | Integration (complete SoC) | ✅ |
| E | Front-end synthesis (Ibex era — superseded) | ✅ |
| F | CPU swap: Ibex → PicoRV32 | ✅ |
| G | Place-and-route (LibreLane) | ✅ |
| H | Signoff: DRC / LVS / antenna / timing | ✅ |

**Final result:** 1000×1000 µm (1.0 mm²), DRC 0, LVS match (13,966 devices /
13,021 nets), antenna 0, timing clean all 9 corners. Healed GDS:
`gds/chip_top_full_healed.gds`.

---

## Phase A — Foundations & Toolchain ✅

| Item | Status |
|------|--------|
| SRAM macro characterization (ports, polarity, read latency) | ✅ |
| Toolchain verified (RISC-V GCC, Icarus/Verilator, GTKWave, LibreLane) | ✅ |
| Core running a hello program in simulation | ✅ |
| Instruction trace verified against objdump | ✅ |

## Phase B — Architecture & Design ✅

| Item | Status |
|------|--------|
| System block diagram | ✅ |
| Memory map (`memory_map.md`) | ✅ |
| Bus architecture (two-tier AHB-Lite + APB) | ✅ |
| Pin budget: 22 pins (20 signal + 2 power), scan-configured control | ✅ |

## Phase C — RTL Block Development ✅

All blocks verified with self-checking testbenches (0 errors). Final set:

| Block | Role |
|-------|------|
| `fetch_gather` / `imem_narrow` | narrow 8-bit instruction memory + byte-gather fetch |
| `dmem_narrow` / `ahb_mem` | narrow 8-bit data memory + scatter/gather + AHB wait-states |
| `mem_subsystem` | imem + dmem + scan-load path |
| `rst_sync` | reset synchronizer (cpu_clk domain — gated clock needs clocked reset) |
| `ibex_to_ahb` | CPU → AHB-Lite master adapter |
| `ahb_interconnect` / `ahb_to_apb` / `apb_decoder` | two-tier bus |
| `gpio`/`apb_gpio` (2 in / 5 out), `uart`/`apb_uart`, `spi`/`apb_spi` | peripherals |
| `scan_chain` | serial load → memory + FSM/clkgen config + readback |
| `test_fsm` | 3-mode clock-gating FSM (idle/run/countdown) |
| `clk_gen` | scan-programmable divider + external fallback |
| `pico_shim` | PicoRV32 native interface → SoC bus (Phase F) |
| `chip_top_full` | complete SoC |

Superseded blocks (`older_version_of_design/`): `sram_bank_2k`, `mem_wrapper`,
`ahb_gpio`, behavioral clk_gen, and the v0.x integration testbenches.

## Phase D — Integration ✅

Incremental top-level bring-up (v0.1–v0.8), each version verified against the
real core: memory → AHB data path → GPIO → UART → SPI → scan-load →
clock generator → complete SoC. Endpoint: one scan-loaded program drives
GPIO + UART + SPI in a single run.

## Phase E — Front-end synthesis (Ibex era) ✅ superseded

Yosys netlist closed timing and fit area on paper (0.845 mm² core estimate),
but hardening exposed the fatal geometry problem: Ibex's only successful
macro was 853×871 µm — 0.743 mm² for the CPU alone, untileable with the
432 µm-wide SRAMs inside a 1000 µm die. Scripts archived in `synthesis/`.

## Phase F — CPU swap: Ibex → PicoRV32 ✅

| Item | Status |
|------|--------|
| PicoRV32 RV32IMC integrated as inline RTL via `pico_shim` (no macro) | ✅ |
| Boot: PROGADDR_RESET=0x0, STACKADDR=0x40; `_start` pinned via `.text.start` | ✅ |
| cpu_clk-domain reset synchronizer (gated clock at boot) | ✅ |
| Memory rightsized: 256 B imem (256×8) + 64 B dmem (64×8) | ✅ |
| Full-chip RTL sim (`tb_chip_v2`): scan-load → RUN → GPIO+UART+SPI | ✅ |
| All 3 firmwares verified on PicoRV32 (primes / piezo_tune / game) | ✅ |

## Phase G — Place-and-route (LibreLane) ✅

| Item | Result |
|------|--------|
| Die | 1000×1000 µm fixed; sram256 @ (40,620), sram64 @ (520,620) |
| Placement closure | hold-buffer cap (HOLD_MAX_BUFFER_PCT=20, margin 0.1) + cell padding 1 — unbounded hold fixing (3055 buffers) had overflowed DPL |
| Antenna closure | targeted heuristic diode insertion (threshold 200, diodes on input ports) |
| Utilization | 72.6 %, 46,344 instances |

## Phase H — Signoff ✅

| Check | Result |
|-------|--------|
| DRC (Magic full) | **0** |
| LVS (netgen) | **match** — 13,966 devices / 13,021 nets |
| Antenna | **0 violations** |
| Setup | +78.08 ns worst @ ss_125C_4v50 (all 9 corners MET) |
| Hold | +0.283 ns worst @ ff_n40C_5v50 (all 9 corners MET) |

**Metal3 heal:** GF180 SRAM + PDN leaves 4 sub-µm Metal3 slivers (OpenLane
#1549 / OpenROAD PR #2814). `gds/heal_metal3.tcl` paints them legal;
DRC + LVS re-verified on the healed GDS. Workflow: librelane → heal → re-verify.

---

## Final specifications

| Parameter | Value |
|-----------|-------|
| CPU | PicoRV32 RV32IMC (MUL/DIV on, IRQ off), std-cell RTL |
| Memory | 256 B imem + 64 B dmem, narrow 8-bit + gather/scatter |
| Peripherals | GPIO (2/5), UART, SPI |
| Bus | Two-tier AHB-Lite + APB |
| Clock | 10 MHz external → ÷2 sys_clk → gated cpu_clk |
| Pins | 22 (20 signal + 2 power) |
| Die | 1000×1000 µm = 1.0 mm² (hard constraint, met) |

## Demo firmware (all verified)

| Program | Demo | Drives |
|---------|------|--------|
| `primes.c` | primes to terminal (MUL/MOD) | UART |
| `piezo_tune.c` | "Happy Birthday" tone | GPIO |
| `game.c` | dodge game on LCD | SPI |

## Remaining (optional)

- Gate-level full-chip TB (`tb_chip_gate_v2`) re-run on the PicoRV32 netlist
- Automate the Metal3 heal as a custom LibreLane flow step
