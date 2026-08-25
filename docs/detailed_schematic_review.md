# Schematic / Design Review — PicoRV32 SoC on GF180MCU

---

## 1. Project Information

|         |                                                                                      |
| ------- | ------------------------------------------------------------------------------------ |
| Team    | A45 — ColumbiaGals                                                                   |
| Program | Chipathon 2026 (IEEE SSCS PICO)                                                      |
| Process | GlobalFoundries GF180MCU (180 nm), open PDK                                          |
| Flow    | Fully open source: LibreLane (Yosys / OpenROAD / Magic / netgen / KLayout)           |
| Design  | `chip_top_full` — single-core RISC-V SoC                                             |
| Repo    | github.com/farihahahmed/pico-soc                                                     |
| Status  | **LVS clean, antenna clean, timing closed on all 9 corners. 4 DRC violations traced to a defect in the GF180 SRAM macro LEF (see §6).** |

---

## 2. Design Objectives

A single-core RISC-V SoC that can be loaded and run on real silicon through 22 pins,
within the A45 slot.

| Spec             | Value                                                                                |
| ---------------- | ------------------------------------------------------------------------------------ |
| CPU              | PicoRV32, RV32E + M + C (16 registers, hardware mul/div, compressed)                 |
| Memory           | Narrow 8-bit SRAM: 512 B instruction + 512 B data = 1 KB, byte gather/scatter        |
| Bus              | Two-tier: AHB-Lite (memory) + APB (peripherals) via bridge                           |
| Peripherals      | GPIO (2 in / 5 out), UART (TX + RX), SPI master (Mode 0, output-only)                |
| Bring-up / debug | Scan chain (program load + FSM/clkgen config) + 3-mode clock-gating FSM              |
| Clock            | 32 ns / 31 MHz; on-chip scan-programmable divider + external-clock fallback          |
| **Die area**     | **1100 × 1100 µm** (A45 slot permits 1110 × 1110)                                    |
| **Pins**         | 22 total (20 signal + 2 power)                                                       |
| Utilization      | 76.3 % — 29,329 standard cells, 10,751 antenna diodes, 2 macros                      |

**Objective (met, verified §6):** a program shifted in over the scan chain loads into
memory; the scan chain configures the FSM to RUN; the CPU boots from 0x0, fetches,
executes, and drives GPIO, UART, and SPI.

---

## 3. System Overview

Three subsystems:

1. **Compute** — PicoRV32 core + narrow instruction/data SRAM macros.
2. **I/O** — GPIO, UART, SPI on a memory-mapped two-tier bus.
3. **Control/debug** — scan chain, clock-gating FSM, clock generator. A fabricated chip
   has no native way to load code, set its clock, or observe state; all three ride the
   scan chain.

**Data flow.** The CPU's native memory interface is adapted by `pico_shim` to the SoC
bus. An AHB-Lite master issues loads/stores; the interconnect decodes `HADDR[17:16]`
and routes to data memory (AHB) or, through the AHB→APB bridge, to a peripheral.
Instruction fetches go through `fetch_gather`, which streams 4 byte-reads from the
8-bit imem and assembles a 32-bit word.

**Clock/reset flow.** `clk_gen` produces the system clock (scan-programmable divider,
or external `clk` when `clk_int`=0). `test_fsm` gates the clock into the CPU:
suppressed during scan-load, passed during run, pulsed N cycles in countdown/debug
mode. Because `cpu_clk` is gated off at boot and PicoRV32 requires a clocked reset, a
dedicated reset synchronizer in the `cpu_clk` domain (`rst_sync`) releases reset only
once the CPU clock is running.

**Boot parameters.** `PROGADDR_RESET = 0x0` (firmware `_start` pinned to 0x0 via
`.text.start` in `link.ld`), `STACKADDR = 0x200` (top of the 512 B data memory).

---

## 4. Schematic Summary — block inventory

| Block                          | Role                                                                | Status |
| ------------------------------ | ------------------------------------------------------------------- | ------ |
| `picorv32`                     | RV32E + M + C core                                                  | ✅      |
| `pico_shim`                    | PicoRV32 native i/f → SoC bus adapter                               | ✅      |
| `imem_narrow` / `fetch_gather` | 512×8 SRAM + byte-gather 32-bit fetch                               | ✅      |
| `dmem_narrow` / `ahb_mem`      | 512×8 SRAM + byte scatter/gather + AHB wait-states                  | ✅      |
| `mem_subsystem`                | imem + dmem + scan-load path                                        | ✅      |
| `ahb_interconnect`             | address decode + response mux                                       | ✅      |
| `ahb_to_apb`                   | AHB→APB bridge (SETUP/ACCESS, wait states)                          | ✅      |
| `apb_decoder`                  | fan-out to GPIO / UART / SPI                                        | ✅      |
| `gpio` / `apb_gpio`            | 2 in / 5 out, 2-flop input synchronizer                             | ✅      |
| `uart` / `apb_uart`            | UART TX + RX, baud gen (STATUS 0x2\_0000 bit0 busy, DATA 0x2\_0004) | ✅      |
| `spi` / `apb_spi`              | SPI master Mode 0, output-only                                      | ✅      |
| `scan_chain`                   | serial loader → memory + FSM/clkgen config                          | ✅      |
| `test_fsm`                     | 3-mode clock-gating FSM (idle/run/countdown)                        | ✅      |
| `clk_gen`                      | scan-programmable divider + external fallback                       | ✅      |
| `rst_sync`                     | cpu\_clk-domain reset synchronizer                                  | ✅      |
| `chip_top_full`                | complete SoC, all blocks wired                                      | ✅      |

**Memory map (`HADDR[17:16]`):**

| Region              | Target                    |
| ------------------- | ------------------------- |
| `00`                | instruction / data memory |
| `01` (0x0001\_xxxx) | GPIO                      |
| `10` (0x0002\_xxxx) | UART                      |
| `11` (0x0003\_xxxx) | SPI                       |

**Pinout (22 pads = 20 signal + 2 power; no bidirectional):** clk, clk_int, rst_n;
scan_in/shift/load/out/i0o1; gpio_in[1:0], gpio_out[4:0]; uart_tx/rx;
spi_sclk/mosi/cs_n; VDD/VSS. FSM control/state are scan-accessed, not pins.
`spi_miso` omitted (output-only LCD interface). See `PINOUT.md`.

---

## 5. Design Assumptions & Known Simplifications

- **Narrow 8-bit memory (key area lever).** Full-width 32-bit banks need 4 macros each.
  Single 8-bit macros fronted by gather/scatter trade a few cycles per access for area.
  Capacity is 512 B code and 512 B data — sufficient for the demo firmware (largest is
  172 B).
- **Scan-configured control.** FSM mode/count and clkgen divide value are scan-written;
  no dedicated control pins.
- **Scan writes memory; readback is not currently functional.** `chip_top_full` ties
  `scan_chain.mem_rdata` to `32'b0`, so the `scan_i0o1` readback path returns zero.
  Program load is verified by executing the loaded program, not by reading it back.
  Wiring readback to the memory read data is open work.
- **Instruction memory is read-only to the core** — only the scan chain writes it,
  during load.
- **Clock generator is a synthesizable divider** with external fallback (`clk_int`) —
  keeps the chip operable if the internal path misbehaves on silicon.
- **SRAM behavioral model wake-up** (clean CEN at reset) is a simulation-only detail;
  RTL control is correct for silicon.

---

## 6. Verification Status

### Functional

Verification environment: cocotb + pyuvm. Official gate
`verification/cocotb/run_all_verify.sh`.

- **Exit gate passes: 12 tests, 0 failures, exit code 0** (2026-08-25), run against
  the signoff RTL.
- Chip-level: smoke (scan-load → FSM RUN → boot → GPIO/UART/SPI), constrained-random,
  dmem read/write.
- Block-level: UART, GPIO, SPI (smoke + directed) in isolation.
- All three demo firmwares execute on the final design and are checked at the pins:
  `primes.c` streams correct primes over UART, `piezo_tune.c` toggles GPIO,
  `game.c` drives SPI. Tests load the real binaries from `firmware/`.

Detail: `VERIFICATION.md`.

### Physical signoff

Artifact: `gds/chip_top_full_signoff.gds` (unmodified LibreLane output).
Run: `openlane/chip_top_full/runs/RUN_2026-08-25_09-23-07`, tag `v2-signoff`.

| Check              | Result                                                            |
| ------------------ | ----------------------------------------------------------------- |
| LVS (netgen)       | **Match uniquely** — 13,972 devices / 13,047 nets                 |
| Antenna            | **PASS** — 0 violations                                           |
| Timing (9 corners) | **Clean.** Setup worst +10.010 ns @ ss; hold worst +0.087 ns @ ff |
| DRC (Magic)        | 4 × M3.1 — see below                                              |
| Die                | 1100 × 1100 µm, 76.3 % utilization                                |
| Power              | 18.0 mW (nom_tt)                                                  |

### Known DRC finding — Metal3 width in the SRAM macro LEF

The four Magic DRC violations (M3.1, Metal3 width < 0.56 µm) are **not produced by
this design**. Every `gf180mcu_fd_ip_sram__sram*x8m8wm1` LEF in the PDK (64, 128, 256
and 512) contains, on the **VSS** pin under `LAYER Metal3`:

```
RECT 118.435 30.885 206.985 30.995 ;
```

That is a port shape 0.110 µm tall against an M3.1 minimum of 0.56 µm. Both macro
instances flag it at identical relative offsets within the macro, and this repository's
LEF copies are md5-identical to the PDK's. Full evidence and method:
`docs/A45_m3_drc_report.txt`.

Raised with the organizers; awaiting guidance on whether to waive.

**Superseded approach.** Earlier revisions patched these slivers by painting Metal3 in
Magic (`gds/heal_metal3.tcl`). That is no longer used: the violations do not originate
in this design's routing, and the patch could not be verified, because the flow's DRC
reads the DEF rather than the GDS. The signoff artifact is the unmodified flow output.

---

## 7. Design Checklist

| Category      | Status | Notes                                                                                          |
| ------------- | ------ | ---------------------------------------------------------------------------------------------- |
| Functionality | ✅      | Full bring-up path proven in simulation; exit gate 12/12; 3 firmwares verified at the pins    |
| Analog        | N/A    | Fully digital design                                                                           |
| Digital       | ✅      | Timing closed all 9 corners; CDC handled (gated cpu\_clk reset sync, GPIO input sync)          |
| Mixed Signal  | N/A    | —                                                                                              |
| Reliability   | ✅      | Antenna clean (diodes on input and output ports, threshold 200); hold margin +0.087 ns @ ff    |
| Documentation | ✅      | README, PINOUT, memory\_map, AREA\_REPORT, TIMING\_REPORT, VERIFICATION, this review           |

---

## 8. Open Issues

1. **DRC waiver pending.** 4 × M3.1 from the SRAM macro LEF (§6). Awaiting organizer
   guidance on how to record the waiver.
2. **Scan readback not wired.** `scan_chain.mem_rdata` is tied to zero at the top level,
   so memory readback returns zero. Program load is instead verified by execution.
3. **Gate-level full-chip TB** has not been re-run on the final netlist. RTL and
   physical signoff are complete; gate-level re-run is optional polish.
4. **Absolute paths in block Makefiles.** The block-level verification Makefiles
   reference `/foss/designs/pico_soc/...`, so the repository builds only at that path.
   Converting to relative paths is straightforward and outstanding.
5. **Clock generator on silicon** — untested by definition; mitigated by the
   external-clock fallback pin.
6. **`cpu_clk` fanout is 2,165 terminals.** Functional, but unusual; restructuring the
   clock tree in RTL is noted as future work.

---

## Appendix

- Signoff artifacts: `gds/` (signoff GDS, DRC result, LVS report, metrics, powered netlist)
- DRC investigation: `docs/A45_m3_drc_report.txt`
- Reports: `AREA_REPORT.md`, `TIMING_REPORT.md`, `memory_map.md`, `PINOUT.md`, `VERIFICATION.md`
- PnR config: `openlane/chip_top_full/config.json`
  (DIE 0,0,1100,1100; CORE 10,10,1090,1090; two `sram512x8` @ [120,300] and [560,300];
  CLOCK_PERIOD 32; DIODE_ON_PORTS both)
- Firmware + linker: `firmware/` (build with `-march=rv32emc -mabi=ilp32e`)
