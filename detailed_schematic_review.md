# Schematic / Design Review — PicoRV32 SoC on GF180MCU

---

## 1. Project Information

| | |
|---|---|
| Team | A45 — ColumbiaGals |
| Program | Chipathon 2026 (IEEE SSCS PICO) |
| Process | GlobalFoundries GF180MCU (180 nm), open PDK |
| Flow | Fully open source: LibreLane (Yosys / OpenROAD / Magic / netgen / KLayout) |
| Design | `chip_top_full` — single-core RISC-V SoC |
| Repo | github.com/farihahahmed/ibex-soc |
| Status | **Tapeout-ready: DRC clean, LVS clean, antenna clean, timing closed on all corners** |

---

## 2. Design Objectives

A single-core RISC-V SoC that can be loaded and run on real silicon through ~20 pins, in 1 mm².

| Spec | Value |
|------|-------|
| CPU | PicoRV32 RV32IMC |
| Memory | Narrow 8-bit SRAM: 256 B instruction (256×8) + 64 B data (64×8), byte gather/scatter |
| Bus | Two-tier: AHB-Lite (memory) + APB (peripherals) via bridge |
| Peripherals | GPIO (2 in / 5 out), UART (TX + RX), SPI master (Mode 0, output-only) |
| Bring-up / debug | Scan chain (program load + FSM/clkgen config + readback) + 3-mode clock-gating FSM |
| Clock | 10 MHz; on-chip scan-programmable divider + external-clock fallback |
| **Die area** | **1000 × 1000 µm = 1.0 mm² (hard constraint — met)** |
| **Pins** | 22 total (20 signal + 2 power) |
| Utilization | 72.6 %, 46,344 placed instances |

**Objective (met, verified §6):** a program shifted in over the scan chain loads into memory; the scan chain configures the FSM to RUN; the CPU boots from 0x0, fetches, executes, and drives GPIO, UART, and SPI.

---

## 3. System Overview

Three subsystems:

1. **Compute** — PicoRV32 core + narrow instruction/data SRAM macros.
2. **I/O** — GPIO, UART, SPI on a memory-mapped two-tier bus.
3. **Control/debug** — scan chain, clock-gating FSM, clock generator. A fabricated chip has no native way to load code, set its clock, or observe state; all three ride the scan chain.

**Data flow.** The CPU's native memory interface is adapted by `pico_shim` to the SoC bus. An AHB-Lite master issues loads/stores; the interconnect decodes `HADDR[17:16]` and routes to data memory (AHB) or, through the AHB→APB bridge, to a peripheral. Instruction fetches go through `fetch_gather`, which streams 4 byte-reads from the 8-bit imem and assembles a 32-bit word.

**Clock/reset flow.** `clk_gen` produces the system clock (scan-programmable divider, or external `clk` when `clk_int`=0). `test_fsm` gates the clock into the CPU: suppressed during scan-load, passed during run, pulsed N cycles in countdown/debug mode. Because `cpu_clk` is gated off at boot and PicoRV32 requires a clocked reset, a dedicated reset synchronizer in the `cpu_clk` domain (`rst_sync`) releases reset only once the CPU clock is running.

**Boot parameters.** `PROGADDR_RESET = 0x0` (firmware `_start` pinned to 0x0 via `.text.start` in `link.ld`), `STACKADDR = 0x40`.

---

## 4. Schematic Summary — block inventory

| Block | Role | Status |
|-------|------|--------|
| `picorv32` | RV32IMC core | ✅ |
| `pico_shim` | PicoRV32 native i/f → SoC bus adapter | ✅ |
| `imem_narrow` / `fetch_gather` | 256×8 SRAM + byte-gather 32-bit fetch | ✅ |
| `dmem_narrow` / `ahb_mem` | 64×8 SRAM + byte scatter/gather + AHB wait-states | ✅ |
| `mem_subsystem` | imem + dmem + scan-load path | ✅ |
| `ahb_interconnect` | address decode + response mux | ✅ |
| `ahb_to_apb` | AHB→APB bridge (SETUP/ACCESS, wait states) | ✅ |
| `apb_decoder` | fan-out to GPIO / UART / SPI | ✅ |
| `gpio` / `apb_gpio` | 2 in / 5 out, 2-flop input synchronizer | ✅ |
| `uart` / `apb_uart` | UART TX + RX, baud gen (STATUS 0x2_0000 bit0 busy, DATA 0x2_0004) | ✅ |
| `spi` / `apb_spi` | SPI master Mode 0, output-only | ✅ |
| `scan_chain` | serial loader → memory + FSM/clkgen config + readback | ✅ |
| `test_fsm` | 3-mode clock-gating FSM (idle/run/countdown) | ✅ |
| `clk_gen` | scan-programmable divider + external fallback | ✅ |
| `rst_sync` | cpu_clk-domain reset synchronizer | ✅ |
| `chip_top_full` | complete SoC, all blocks wired | ✅ |

**Memory map (`HADDR[17:16]`):**

| Region | Target |
|--------|--------|
| `00` | instruction / data memory |
| `01` (0x0001_xxxx) | GPIO |
| `10` (0x0002_xxxx) | UART |
| `11` (0x0003_xxxx) | SPI |

**Pinout (22 pads = 20 signal + 2 power; no bidirectional):** clk, clk_int, rst_n; scan_in/shift/load/out/i0o1; gpio_in[1:0], gpio_out[4:0]; uart_tx/rx; spi_sclk/mosi/cs_n; VDD/VSS. FSM control/state are scan-accessed, not pins. `spi_miso` omitted (output-only LCD interface). See `PINOUT.md`.

---

## 5. Design Assumptions & Known Simplifications

- **Narrow 8-bit memory (key area lever).** Full-width 32-bit banks need 4 macros each and do not fit 1 mm². Single 8-bit macros fronted by gather/scatter trade a few cycles per access for area. Capacity is small (256 B code, 64 B data) but sufficient for the demo firmware.
- **Scan-configured control.** FSM mode/count and clkgen divide value are scan-written; no dedicated control pins.
- **Scan reaches memory, not CPU registers.** Readback verifies memory contents; live register scan not implemented.
- **Instruction memory is read-only to the core** — only the scan chain writes it, during load.
- **Clock generator is a synthesizable divider** with external fallback (`clk_int`) — keeps the chip operable if the internal path misbehaves on silicon.
- **SRAM behavioral model wake-up** (clean CEN at reset) is a simulation-only detail; RTL control is correct for silicon.

---

## 6. Verification Status

### Functional
- Every block passes a self-checking testbench (0 errors) — see `tb/`.
- Full-chip RTL (`tb_chip_v2`): scan-load → FSM RUN → boot → drives GPIO, UART, SPI in one run. ✅
- All three demo firmwares verified on the PicoRV32 design: `primes.c` streams correct primes over UART, `piezo_tune.c` plays tones on GPIO, `game.c` drives an SPI LCD game. ✅

### Physical signoff (healed GDS: `gds/chip_top_full_healed.gds`)

| Check | Result |
|-------|--------|
| DRC (Magic full) | **0 violations** |
| LVS (netgen) | **Match** — 13,966 devices / 13,021 nets |
| Antenna | **PASS** — 0 violations |
| Timing (9 corners) | **Clean.** Setup worst +75.07 ns @ ss; hold worst +0.328 ns @ ff |
| Die | 1000 × 1000 µm, 72.6 % util, 46,344 instances |

### Known signoff detail — Metal3 heal
The GF180 SRAM + PDN interaction leaves 4 sub-µm Metal3 slivers (known upstream issue: OpenLane #1549 / OpenROAD PR #2814). Post-processing script `gds/heal_metal3.tcl` paints them to legal width; DRC and LVS are re-verified on the healed GDS. Workflow: librelane → heal → re-verify.

---

## 7. Design Checklist

| Category | Status | Notes |
|----------|--------|-------|
| Functionality | ✅ | Full bring-up path (scan-load → run → all peripherals) proven in RTL sim; 3 firmwares verified |
| Analog | N/A | Fully digital design |
| Digital | ✅ | Timing closed all 9 corners; CDC handled (gated cpu_clk reset sync, GPIO input sync) |
| Mixed Signal | N/A | — |
| Reliability | ✅ | Antenna clean (targeted diode insertion, threshold 200); hold margin +0.328 ns @ ff |
| Documentation | ✅ | README, PINOUT, memory_map, AREA_REPORT, TIMING_REPORT, this review |

---

## 8. Open Issues

1. **Gate-level full-chip TB** (`tb_chip_gate_v2`) has not been re-run on the final PicoRV32 netlist (it passed on an earlier design revision). RTL + physical signoff are complete; gate-level re-run is optional polish.
2. **Metal3 heal is a manual post-step** — every librelane rerun regenerates the slivers and must be followed by the heal + re-verify. Automating it as a custom LibreLane step is feasible but deferred.
3. **Clock generator on silicon** — untested by definition; mitigated by the external-clock fallback pin.

---

## Appendix

- Signoff artifacts: `gds/` (healed GDS, DRC result, LVS report, metrics, heal script)
- Reports: `AREA_REPORT.md`, `TIMING_REPORT.md`, `memory_map.md`, `PINOUT.md`
- PnR config: `openlane/chip_top_full/config.json` (DIE 0,0,1000,1000; sram256 @ [40,620], sram64 @ [520,620])
- Firmware + linker: `firmware/`
