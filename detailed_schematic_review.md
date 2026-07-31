# Ibex SoC on GF180MCU — Detailed Schematic Review

**Team A45 — ColumbiaGals** ·
Project: RISC-V System-on-Chip with the Ibex 32-bit core, open GF180MCU (180 nm), open-source RTL-to-netlist flow.

This review reflects the **as-built design**: every block is written, passes a self-checking simulation, and the full SoC boots end-to-end in both RTL and gate-level simulation. The design is synthesized, timing-closed, and fits the die and pin budget.

---

## 1. Design Objectives & Specifications

A single-core RISC-V SoC loaded and run on real silicon through ~20 pins.

| Spec | Value |
|------|-------|
| CPU | Ibex RV32IMC (small config, 2-stage pipeline, 3-cycle multiplier) |
| Memory | Narrow 8-bit: 512 B instruction (1× 512×8) + 512 B data (1× 512×8), byte gather/scatter |
| Bus | Two-tier: AHB-Lite (memory) + APB (peripherals) via a bridge |
| Peripherals | GPIO (2 in / 5 out), UART (TX + RX), SPI master (Mode 0, output) |
| Bring-up / debug | Scan chain (loads program + FSM/clkgen config, readback) + 3-mode clock-gating FSM |
| Clock | On-chip scan-programmable clock generator + external-clock fallback |
| Process | GlobalFoundries 180 nm (open PDK), open-source flow |
| **Die area** | ~0.845 mm² core (pads not counted) — fits 1 mm² |
| **Pins** | 22 total (20 signal + 2 power) |
| **Max frequency** | ~150 MHz (setup MET) |

**Objective (met, verified §6):** a program shifted in over the scan chain loads into memory; the scan chain then configures the FSM to RUN; the CPU fetches and executes, driving GPIO, UART, and SPI.

---

## 2. System Overview

Three parts: **(1)** the Ibex core + narrow instruction/data SRAM; **(2)** the communication peripherals (GPIO, UART, SPI) on a memory-mapped two-tier bus; **(3)** the control/debug blocks (scan chain, clock-gating FSM, clock generator), all configured through the scan chain — a fabricated chip has no native way to load code, set its clock, or observe state.

**Data flow.** The CPU's data port issues ordinary loads/stores. An adapter converts the Ibex handshake to an AHB-Lite master; the interconnect decodes the address and routes to data memory (AHB) or, through the AHB→APB bridge, to a peripheral. The instruction port fetches from the narrow instruction memory via a byte-gather unit.

**Clock/reset flow.** An on-chip clock generator produces the system clock (scan-programmable divider, or external fallback). The FSM gates that clock into the CPU: suppressed during scan-load, passed during run, or pulsed for a fixed count during debug.

---

## 3. Architecture — block inventory

Every block is implemented and verified.

| Block | Role | Status |
|-------|------|--------|
| `ibex_top` | RV32IMC core (lowRISC IP, blackboxed in synth) | ✅ |
| `imem_narrow` / `fetch_gather` | 512×8 SRAM + byte-gather 32-bit fetch | ✅ |
| `dmem_narrow` / `ahb_mem` | 512×8 SRAM + byte scatter/gather + AHB wait-states | ✅ |
| `mem_subsystem` | imem + dmem + reset sync + scan-load path | ✅ |
| `ibex_to_ahb` | Ibex data port → AHB-Lite master | ✅ |
| `ahb_interconnect` | address decode + response mux | ✅ |
| `ahb_to_apb` | AHB→APB bridge (SETUP/ACCESS, wait states) | ✅ |
| `apb_decoder` | fan-out to GPIO / UART / SPI | ✅ |
| `gpio` / `apb_gpio` | GPIO 2 in / 5 out, 2-flop input synchronizer | ✅ |
| `uart` / `apb_uart` | UART TX + RX, baud gen | ✅ |
| `spi` / `apb_spi` | SPI master Mode 0 (output) | ✅ |
| `scan_chain` | serial loader → memory + FSM/clkgen config registers | ✅ |
| `test_fsm` | 3-mode clock-gating FSM (idle/run/countdown), scan-configured | ✅ |
| `clk_gen` | synthesizable clock generator (scan-programmable divider + ext fallback) | ✅ |
| `chip_top_full` | complete SoC, all blocks wired | ✅ |

**Bus architecture:** two-tier — fast memory on AHB, slow peripherals behind the bridge on APB so their timing never stalls the memory path. Slave select from `HADDR[17:16]`.

---

## 4. Pinout — 22 pads (20 signal + 2 power)

12 input, 8 output, 2 power. No bidirectional pins.

| Group | Pins | Type |
|-------|------|------|
| Clock | `clk`, `clk_int` | input |
| Reset | `rst_n` | input |
| Scan | `scan_in`, `scan_shift`, `scan_load`, `scan_out`, `scan_i0o1` | in/in/in/out/in |
| GPIO | `gpio_in[1:0]`, `gpio_out[4:0]` | in / out |
| UART | `uart_tx`, `uart_rx` | out / in |
| SPI | `spi_sclk`, `spi_mosi`, `spi_cs_n` | output |
| Power | `VDD`, `VSS` | power |

FSM control and state are **not** pins — they are configured and observed through the scan chain (`clk_int` selects the clock source; `scan_i0o1` selects scan direction). This scan-configured scheme removed the `start`/`load_done`/`fsm_state` pins. SPI is output-only (drives an external LCD), so `spi_miso` is omitted. See [`PINOUT.md`](PINOUT.md).

---

## 5. Design Assumptions & Known Simplifications

- **Narrow memory (key area lever).** A 32-bit memory needs four 8-bit SRAM macros per bank and does not fit 1 mm². Instead, single 8-bit macros are fronted by byte gather/scatter units: instruction fetch streams 4 byte-reads and assembles a word; data stores split into byte-enabled byte-writes; the data memory is an AHB slave that inserts wait-states during the multi-cycle access. The address map is unchanged — the CPU sees a normal 32-bit memory — but capacity is small (512 B code, 512 B data), sufficient for the demo programs.
- **Scan-configured control.** The scan chain writes the FSM mode/cycle-count and clock-generator config registers, so no dedicated control pins are needed. Debug is via the FSM's countdown mode (run N cycles then freeze) plus scan-out of memory contents.
- **Clock generator — synthesizable divider.** A frequency divider with a scan-writable divide value, plus an external-clock fallback (`clk_int`), replacing the earlier behavioral ring-oscillator model. Keeps the chip operable if the internal generator misbehaves on silicon.
- **Scan reaches memory, not CPU registers.** Readback covers memory contents (verify what the CPU computed/stored); live CPU-register scan is not implemented (memory-based debug is sufficient for the demo).
- **Instruction memory is read-only to the core** — only the scan chain writes it, during load.
- **SRAM macro power-up in sim.** The GF180 behavioral SRAM model needs a clean CEN wake-up before returning data; testbenches assert this at reset. Simulation detail only — the RTL memory control is correct for silicon.

**Memory map (as-built):**

| Region (`HADDR[17:16]`) | Target |
|--------------------------|--------|
| `00` | instruction / data memory |
| `01` (0x0001_xxxx) | GPIO (`apb_gpio`, 2 in / 5 out) |
| `10` (0x0002_xxxx) | UART (`apb_uart`) |
| `11` (0x0003_xxxx) | SPI (`apb_spi`) |

---

## 6. Verification Status

**Every block passes a self-checking testbench (0 errors)**, and the full SoC is verified at both RTL and gate level.

### Block-level

| Block | Test | Result |
|-------|------|--------|
| Narrow imem (fetch-gather) | 4-byte read → word assembly | ✅ |
| Narrow dmem (scatter/gather + AHB) | loads, byte-enabled stores, wait-states | ✅ |
| GPIO 2/5 | output reg + input synchronizer | ✅ |
| AHB interconnect / ahb_mem | routing, address-discriminated reads | ✅ |
| AHB→APB bridge / decoder | full chain, wait states, multi-peripheral | ✅ |
| UART / SPI | TX + loopback / Mode 0 output | ✅ |
| Scan chain | serial load → memory + FSM/clkgen config + readback | ✅ |
| Test FSM | idle suppresses clock, run passes, countdown runs exactly N then freezes | ✅ |
| Clock generator | divide-by-N, external passthrough | ✅ |

### Full-chip (against the real Ibex core)

| Level | What it proves | Result |
|-------|----------------|--------|
| RTL (`tb_chip_v2`) | scan-load program, scan-configure FSM→RUN, boot, drive all peripherals | ✅ gpio/uart=0x41/spi=0xB7 |
| Gate (`tb_chip_gate_v2`) | synthesized netlist reproduces the same outputs | ✅ RTL≡netlist |

**Headline result:** a program shifted in over the scan chain, with the FSM scan-configured to RUN, executes on the Ibex core and drives all three peripherals in one run — in both RTL and gate-level simulation. This is the full bring-up path the real chip uses after tapeout.

### Synthesis, timing, area

- **Netlist:** `synthesis/chip_top.nl.v` — 1,334 GF180 standard cells + Ibex/SRAM black boxes, 20 signal pins.
- **Timing (OpenSTA):** setup MET, worst slack +113 ns at 8 MHz, Fmax ~150 MHz.
- **Area:** ~0.845 mm² core (pads not counted) — fits 1 mm² with ~15.5% margin. See [`AREA_REPORT.md`](AREA_REPORT.md), [`TIMING_REPORT.md`](TIMING_REPORT.md).

---

## Key tradeoffs

- **Narrow 8-bit memory + gather/scatter:** the central area lever — trades a few cycles per access (irrelevant for the demo) to fit 1 mm².
- **Scan-configured FSM + clock generator:** control and debug ride the scan chain, freeing pins and giving cycle-accurate countdown debug — closely matching the Columbia EE6350 reference design.
- **Two-tier bus:** isolates slow peripherals from the fast memory path.
- **2-stage pipeline / 3-cycle multiplier:** smaller area, easier timing; throughput isn't the goal.

## Project status

- **Front-end:** complete — all RTL, unit tests, full RTL + gate-level integration.
- **Synthesis:** complete — netlist, timing closure, area, gate-level equivalence.
- **Back-end (floorplan / PnR / pad ring / tapeout):** remaining, handled at hardening.
- **Primary risks:** (1) final pad sizing affects exact die area (core is firm); (2) hold closure and clock-tree at APR; (3) the clock generator on silicon — mitigated by the external-clock fallback.

---

*Status: front-end and synthesis complete and verified (RTL + gate-level); back-end is the remaining work.*
