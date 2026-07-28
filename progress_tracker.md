# Ibex SoC on GF180MCU — Progress Tracker
A from-scratch RISC-V System-on-Chip built on the open-source **GF180MCU (180nm)** process, using the Ibex RV32IMC core. Front-end flow: RTL → simulation → synthesized netlist.
**Legend:** ✅ done & verified  🚧 in progress  ⬜ not started
---
## Status at a glance
| Phase | Description | Status |
|-------|-------------|--------|
| A | Foundations & toolchain | ✅ |
| B | Architecture & design | ✅ |
| C | RTL block development | 🚧 (9/12) |
| D | Integration | 🚧 (v0.3 ✅) |
| E | Synthesis → netlist | ⬜ |
---
## Phase A — Foundations & Toolchain ✅
| Item | Status |
|------|--------|
| SRAM macro characterization (ports, polarity, read latency) | ✅ |
| Toolchain verified (RISC-V GCC, Verilator, GTKWave) | ✅ |
| Ibex Simple System running `hello_test` in simulation | ✅ |
| Instruction trace verified against objdump | ✅ |
| riscv-tests ISA suite | ⬜ (deferred, optional) |
## Phase B — Architecture & Design ✅
| Item | Status |
|------|--------|
| System block diagram | ✅ |
| Memory map definition (`memory_map.md`) | ✅ |
| Design hierarchy (synthesized vs. macro) | ✅ |
| Bus architecture (two-tier AHB-Lite + APB) | ✅ |
## Phase C — RTL Block Development 🚧
| Block | Description | Verification | Status |
|-------|-------------|--------------|--------|
| `sram_bank_2k` | 2 KB bank (4× 512×8 macros, byte-lane writes) | 10 checks, 0 errors | ✅ |
| `mem_wrapper` | Ibex req/gnt/rvalid → SRAM interface | reads/writes, 0 errors | ✅ |
| `rst_sync` | Two-flop reset synchronizer (async assert, sync de-assert) | timing checks, 0 errors | ✅ |
| `mem_subsystem` | rst_sync + 2× (wrapper+bank): imem + dmem | both ports, 0 errors | ✅ |
| `gpio` | 8-pin GPIO, output reg + 2-flop input synchronizer | 4 checks, 0 errors | ✅ |
| `ibex_to_ahb` | Ibex req/gnt/rvalid → AHB-Lite master adapter | via bus + integration tests | ✅ |
| `ahb_interconnect` | AHB-Lite address decoder + response mux | routing + one-hot, 0 errors | ✅ |
| `ahb_mem` | Data memory as AHB-Lite slave (zero-wait, self-contained) | address-discriminated reads, 0 errors | ✅ |
| `ahb_gpio` | GPIO as AHB-Lite slave (single-tier variant) | via bus tests | ✅ |
| `ahb_to_apb` | AHB → APB bridge | full chain, wait-state verified | ✅ |
| `apb_decoder` | APB address decode / fan-out to GPIO/UART/SPI | multi-peripheral routing, 0 errors | ✅ |
| `apb_gpio` | GPIO as APB slave (two-tier variant) | via bus + integration tests | ✅ |
| `uart` | UART TX + RX, baud generator, separate status/data regs | loopback + bus, 0 errors | ✅ |
| `apb_uart` | UART as APB slave | full chain, 0 errors | ✅ |
| `spi` | SPI master (Mode 0), clock divider + shift FSM | loopback, 0 errors | ✅ |
| `apb_spi` | SPI as APB slave | full chain, 0 errors | ✅ |
| `scan_chain` | 248-cell scan chain (program load) | — | ⬜ |
| `clk_gen` | Ring-oscillator clock generator | — | ⬜ |
| `test_fsm` | Debug gating FSM | — | ⬜ |

The full two-tier bus (Ibex → AHB-Lite → bridge → APB → peripherals) is verified end-to-end, with GPIO, UART, and SPI on APB at their memory-map addresses.

## Phase D — Integration 🚧

Integration proceeds incrementally: each version wires one additional block into
`chip_top` and is verified against the **real Ibex core** (not a testbench master)
via a small self-checking smoke test. All integration smoke tests build with
Verilator (Ibex requires it) and run a short hand-assembled RV32I program loaded
into instruction memory. Because the GF180 SRAM behavioral model requires a clean
power-up (CEN wake-up) before it returns data, the smoke-test harnesses assert the
macros' operational state at reset; this is a simulation bring-up step only — the
RTL memory control (`cen = ~cs`) is correct for silicon.

| Milestone | Description | Status |
|-----------|-------------|--------|
| v0.1 | Memory subsystem + Ibex — CPU executes a program from custom SRAM | ✅ |
| v0.2 | Data path routed through the AHB bus to memory (store + load verified) | ✅ |
| v0.3 | GPIO on the bus — CPU drives output pins through AHB→bridge→APB→GPIO | ✅ |
| v0.4 | UART on the bus (TX/RX) | ⬜ |
| v0.5 | SPI on the bus | ⬜ |
| v0.6 | Scan chain (load program, run) | ⬜ |
| v0.7 | Clock generator + test FSM | ⬜ |
| v0.8 | Full `chip_top`, multi-function demo | ⬜ |

### v0.1 — Ibex + memory subsystem
`chip_top` instantiates `ibex_top` (RV32IMC, ICache/PMP/DbgTrigger off, `RV32MFast`)
with both memory ports wired directly to `mem_subsystem` (instruction → imem,
data → dmem). Ibex tie-offs (integrity, icache config, scramble, debug, interrupts,
alerts, shadows) follow the `ibex_simple_system` reference. `fetch_enable_i` is
asserted; `boot_addr_i = 0`, so the reset fetch is at `0x80`.
**Smoke test (`tb_chip_smoke*`):** loads a 4-instruction program (`addi`/`jal`) into
imem at the boot offset, releases reset, and probes the fetch address and PC. The
PC advances `0x80 → 0x84 → 0x88 → 0x8C` and loops at the `jal`, with the real
instruction words read back from SRAM — the core executes from custom memory.
Verilator lint clean (142 modules, no errors).

### v0.2 — data path through the AHB bus
The data port is moved off the direct connection and onto the bus:
`Ibex data → ibex_to_ahb → ahb_interconnect → ahb_mem` (slave 0, self-contained
data memory). The instruction port remains direct to imem. Slaves 1–3 tied off.
**Smoke test (`tb_chip_v02`):** program stores `0x2A2` to `0x0000_0800` then loads
it back; the harness watches the AHB data bus. The store and load both route
correctly and the loaded value matches (`0x2A2`).
**Bug found & fixed:** `ibex_to_ahb` only pulsed `rvalid` for reads, so Ibex's LSU
never saw stores complete and stalled. Changed the in-flight tracking to cover any
granted access (read or write); `rvalid` now acknowledges writes. All five
standalone bus/peripheral testbenches were re-run after the change and still pass.

### v0.3 — GPIO on the bus
The peripheral tier is added as slave 1: `ahb_interconnect[1] → ahb_to_apb →
apb_decoder → apb_gpio`. `gpio_out`/`gpio_in` are brought to the top level.
UART/SPI decoder ports are tied off pending v0.4/v0.5.
**Smoke test (`tb_chip_v03`):** program builds the GPIO base address with `lui`,
stores `0xA5` to `0x0001_0000`, and loops. The output pins reach `0xA5` and hold —
the CPU drives external pins through the full two-tier fabric. Verilator lint clean.

## Phase E — Synthesis → Netlist ⬜
| Item | Status |
|------|--------|
| Yosys synthesis script (macros black-boxed) | ⬜ |
| Timing/area report | ⬜ |
| Setup-violation closure | ⬜ |
| Gate-level simulation (RTL vs. netlist equivalence) | ⬜ |
| `chip_top.nl.v` — deliverable netlist | ⬜ |
---
## Target specifications
| Parameter | Value |
|-----------|-------|
| CPU | Ibex RV32IMC |
| Memory | 4 KB SRAM (2 KB instruction / 2 KB data) |
| Peripherals | GPIO, UART, SPI |
| Bus | Two-tier AHB-Lite + APB |
| Process | GF180MCU (180nm) |
| Core area budget | 2051 × 2051 µm |
## Repository layout
## Repository layout

ibex_soc/
├── rtl/ # synthesizable design (.sv)
├── tb/ # self-checking testbenches
├── memory_map.md
└── README.md

## Running a testbench
```bash
iverilog -g2012 -o sim -s tb_sram_bank \
  tb/tb_sram_bank.sv rtl/sram_bank_2k.sv \
  /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram__sram512x8m8wm1.v
vvp sim
```
Integration smoke tests build with Verilator against the full Ibex source list; see
the `tb_chip_v0*` testbenches.
