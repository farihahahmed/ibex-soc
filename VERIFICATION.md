# Pico SoC — Verification Report

**Last updated:** 2026-08-23  
**Official gate:** `verification/cocotb/run_all_verify.sh` — exit **0** required (all included tests PASS; no `fail_ok` / known-fail exceptions).

---

## 1. Summary

| Area | Implementation | Status |
|------|----------------|--------|
| Methodology | Metric-driven verification: plan → stimulus → scoreboard → coverage → close holes | Implemented |
| Chip-level TB | pyuvm + cocotb; scan, GPIO, UART, SPI agents; scoreboard | Green |
| Block-level MDV | Isolated UART, GPIO, SPI benches (scan / AHB / FSM where present) | Green |
| Constrained-random | Multi-seed GPIO / UART / SPI; coverage merge | Green |
| Firmware self-check | `primes`, `piezo_tune`, `game` via scan; pin-level checks | Green |
| Negative tests | Scan lockout under RUN; FSM IDLE clock hold; AHB HREADY stall | Green |
| Code coverage | Verilator line/toggle; glue-line gate (~70%, excluding CPU + SRAM models) | Documented |
| Gate-level | Post-PnR netlist smoke | Smoke green |
| Packaging | FuseSoC targets; one-button freeze; requirements→tests table | Present |

Chip and block verification share agents and scoreboarding. Constrained-random, firmware demos, and negative corners are part of the same official gate.

---

## 2. Design under test

| Item | Value |
|------|--------|
| Top | `chip_top_full` |
| CPU | PicoRV32 (RV32IMC as configured in RTL) |
| Boot | Scan-chain IMEM load; FSM **RUN** ungates `cpu_clk` |
| Peripherals | GPIO `0x0001_0000`, UART `0x0002_0000`, SPI `0x0003_0000` |
| Memory | Narrow 8-bit SRAM + gather/scatter (IMEM 256 B, DMEM 64 B) |
| Implementation | GF180MCU; OpenLane / LibreLane physical flow (outside this report) |

RTL: `rtl/chip_top_full.sv` and modules under `rtl/`.  
Address map: `memory_map.md`.

---

## 3. Verification architecture

### 3.1 Hierarchy

```
Tests (pyuvm / cocotb)
  smoke · random · primes · piezo · game · dmem · RX E2E · lockout …
      │
Sequences (scan load, firmware load, APB, start CPU)
      │
Environment (agents + scoreboard + coverage)
  ┌─────────┬─────────┬─────────┬─────────┐
  │ Scan    │ GPIO    │ UART    │ SPI     │
  │ agent   │ agent   │ agent   │ agent   │
  └─────────┴─────────┴─────────┴─────────┘
      │
DUT: chip_top_full  |  block DUT (apb_uart / apb_gpio / apb_spi / …)
```

### 3.2 Stack

| Component | Choice |
|-----------|--------|
| Functional simulator | Icarus Verilog |
| TB language | Python (cocotb + pyuvm) |
| Structure | UVM phases, agents, sequencers, analysis ports |
| Block bus VIP | APB driver + monitor |
| Coverage | Functional (Python) + Verilator code coverage |
| Packaging | FuseSoC `::pico_soc:1.0.0` (`sim` / `pyuvm` / `block` / honesty) |
| Gate-level | Post-PnR netlist + Icarus |

### 3.3 Directory map

| Path | Contents |
|------|----------|
| `verification/cocotb/` | Chip Makefile, tests, coverage tools, freeze scripts |
| `verification/cocotb/tb/` | Env, agents (scan, gpio, uart, spi, apb), scoreboard, sequences, coverage |
| `verification/cocotb/block/` | Block MDV: `uart/`, `gpio/`, `spi/` (+ `scan/`, `ahb/`, `fsm/` as present) |
| `verification/cocotb/models/` | Behavioral SRAM models |
| `verification/cocotb/coverage_rtl/` | Verilator model, `sim_main.cpp`, annotate |
| `verification/docs/` | Gates, coverage policy, architecture notes |
| `verification/gl/` | Gate-level smoke |
| `firmware/` | `primes`, `piezo_tune`, `game` |
| `scripts/` | Honesty / FuseSoC wrappers |
| `pico_soc.core` | FuseSoC CAPI-2 description |

---

## 4. Chip-level verification

DUT: `chip_top_full`. Flow: scan-load → FSM RUN → observe GPIO / UART / SPI.

### 4.1 Tests

| Module | Intent | Target |
|--------|--------|--------|
| `test_pyuvm_smoke` | Scan boot; directed program; expected GPIO / flow events | `make smoke` |
| `test_pyuvm_random` | Constrained-random GPIO; scoreboard; `RANDOM_SEED` | `make random` |
| `test_pyuvm_random_uart` | Constrained-random UART TX | `make random-uart` |
| `test_pyuvm_random_spi` | Constrained-random SPI activity | `make random-spi` |
| `test_pyuvm_primes` | `firmware/primes.bin`; UART prime stream | `make primes` |
| `test_pyuvm_piezo` | Piezo firmware; GPIO[0] toggles | `make piezo` |
| `test_pyuvm_game` | `game.bin`; SPI activity | `make game` |
| `test_pyuvm_dmem` | Directed SW/LW; value on GPIO | `make dmem` |
| `test_pyuvm_uart_rx_e2e` | Bit-bang RX → STATUS/DATA → GPIO | RX E2E target |
| `test_pyuvm_scan_lockout` | RUN: scan cannot rewrite IMEM | `make scan-lockout` |

```bash
cd verification/cocotb
export PYTHONPATH="$(pwd):${PYTHONPATH}"
make pyuvm-regress
./run_all_verify.sh
```

### 4.2 Scoreboard

- Required flow events (e.g. `program_loaded`, `cpu_started`)
- Expected GPIO when programmed
- UART bytes when expected
- SPI activity when applicable  

Missing required events fail `check_phase`.

### 4.3 Constrained-random

- Seed via `RANDOM_SEED` (or cocotb seed env)
- Multi-seed runs accumulate `gpio_value` bins
- Merge: `python3 merge_coverage.py` → `coverage_merge.json`
- Practical diversity target: ≥ 5 distinct GPIO bins (30-seed sweeps typically yield many more)

```bash
RANDOM_SEED=42 make random
python3 merge_coverage.py
```

---

## 5. Block-level MDV

Peripherals are verified in isolation (wrapper + core, no full CPU).

### 5.1 Pattern

1. DUT = APB wrapper + peripheral (`apb_uart`/`uart`, `apb_gpio`/`gpio`, `apb_spi`/`spi`)
2. Active APB master (setup + access on `PCLK`)
3. Directed register/pin checks
4. Monitor / scoreboard as applicable
5. Targets under `verification/cocotb/block/<name>/`

### 5.2 Block matrix

| Block | Path | Checks | Status |
|-------|------|--------|--------|
| UART | `block/uart/` | Idle TX; directed TX byte → serial activity | PASS |
| GPIO | `block/gpio/` | Reset `gpio_out=0`; write `0x15` → pin match | PASS |
| SPI | `block/spi/` | `cs_n` idle high; write `0xA5` → `cs_n` low, ≥16 SCLK edges | PASS |
| Scan | `block/scan/` (if present) | Frame decode → MEM / FSM / CLKGEN | PASS when present |
| AHB | `block/ahb/` (if present) | Decode, HRDATA mux, HREADY stall | PASS when present |
| FSM | `block/fsm/` (if present) | RUN ungates clock; IDLE holds `cpu_clk` | PASS when present |

```bash
./run_block_regress.sh
make -C block/gpio MODULE=test_gpio_write COCOTB_TEST_MODULES=test_gpio_write
make -C block/spi  MODULE=test_spi_tx     COCOTB_TEST_MODULES=test_spi_tx
```

### 5.3 APB VIP

| File | Role |
|------|------|
| `tb/agents/apb/item.py` | Transfer item |
| `tb/agents/apb/driver.py` | Setup/access driver |
| `tb/agents/apb/monitor.py` | Sample `PSEL & PENABLE` |
| `tb/agents/apb/agent.py` | Sequencer + driver + monitor |

---

## 6. Coverage

### 6.1 Functional (primary)

- Scoreboard / `tb/coverage.py` (and related helpers)
- Flow events, `gpio_value` bins, random-pass markers
- Merge across seeds → `coverage_merge.json`
- Required events not hit → test fails

### 6.2 RTL code coverage (Verilator)

| Item | Detail |
|------|--------|
| Tool | Verilator `--coverage` |
| Harness | `coverage_rtl/sim_main.cpp` |
| Data | `coverage_rtl/obj_dir/coverage.dat` |
| Annotate | `verilator_coverage --annotate coverage_rtl/annotate …` |
| Policy | `verification/docs/CODE_COVERAGE.md` |

**Glue-line gate:** fabric + peripherals, excluding `picorv32` and GF180 SRAM models — target ~70% line. Overall toggle is secondary (wide buses). Single-word dmem does not saturate `dmem_narrow_top` line points; functional SW/LW is covered by `make dmem`.

```bash
cd verification/cocotb
# see Makefile coverage-rtl / CODE_COVERAGE.md
verilator_coverage --rank coverage_rtl/obj_dir/coverage.dat
```

---

## 7. Firmware

| Program | Constraint | Check |
|---------|------------|--------|
| `primes` | ≤ 256 B IMEM | UART prime stream |
| `piezo_tune` | ≤ 256 B IMEM | GPIO[0] activity |
| `game` | ≤ 256 B IMEM | SPI sclk/mosi activity |

Sources and link script: `firmware/` (`link.ld` places code at `0x0`; stack within 64 B dmem). Piezo rebuilt as RV32I where the core configuration required it (no C / no halfword loads).

---

## 8. Negative tests

| Test | Intent | Entry |
|------|--------|--------|
| Scan lockout | Under RUN, scan must not rewrite IMEM | `make scan-lockout` |
| FSM IDLE hold | `cpu_clk` remains gated in IDLE | Block FSM idle-hold |
| AHB HREADY stall | Slave HREADY low stalls master | Block AHB hready-stall |
| UART RX E2E | External RX → FW read → GPIO | RX E2E test |

Included in the official gate where implemented.

---

## 9. Gate-level

| Item | Detail |
|------|--------|
| Scope | Post-PnR netlist smoke |
| Entry | `make gl` / `verification/gl` |
| Status | Smoke path green |
| Open | Automated GL↔RTL compare; full firmware on GL |

Related PD notes (not sim): `TIMING_REPORT.md`, `AREA_REPORT.md`, `PINOUT.md`.

---

## 10. Infrastructure

### 10.1 Gates

| Entry | Scope |
|-------|--------|
| `./run_all_verify.sh` | Full official freeze |
| `./run_block_regress.sh` | Block MDV |
| `make pyuvm-regress` | Chip pyuvm suite |
| `make lint` | Lint where wired |
| `scripts/run_honesty_freeze.sh` | FuseSoC-facing wrapper |

Exit code **0** only if every included test PASSes.

### 10.2 FuseSoC

`pico_soc.core` → `::pico_soc:1.0.0`

| Target | Role |
|--------|------|
| `sim` | Filelist + Icarus setup |
| pyuvm / honesty | Full freeze via scripts |
| `block` | Block regress entry |

```bash
fusesoc core-info ::pico_soc:1.0.0
fusesoc run --target sim --setup --build ::pico_soc:1.0.0
bash scripts/run_honesty_freeze.sh
```

### 10.3 Environment

```bash
cd verification/cocotb
# activate project venv if used
export PYTHONPATH="$(pwd):${PYTHONPATH}"
make smoke
./run_all_verify.sh
```

Icarus + cocotb 2.x + pyuvm as installed for the project.

---

## 11. Requirements → tests

Full matrix: `REQUIREMENTS_TRACEABILITY.md`.

| Domain | Examples | Evidence |
|--------|----------|----------|
| Boot / scan / FSM | IMEM load; RUN ungates clock; IDLE holds clock; RUN lockout | smoke, block scan/fsm, `scan-lockout` |
| Map / fabric | GPIO/UART/SPI bases; AHB decode/mux/stall | chip + block AHB |
| Peripherals | UART TX/RX, GPIO R/W, SPI transfer | block + chip |
| Memory | IMEM execute; DMEM SW/LW | FW, `make dmem` |
| Gate-level | Netlist smoke | `make gl` |
| Process | One-button gate, FuseSoC, written exit criteria | scripts + docs |

Not claimed closed (if still open on the tree): systematic illegal-address test in gate; dense concurrent multi-peripheral stress; dense narrow-mem FSM stress beyond single-word dmem; automated GL↔RTL; CI on real runners (skeleton only if present).

---

## 12. Exit criteria

Defined in `verification/docs/VERIFICATION_GATES.md`.

1. `./run_all_verify.sh` exits 0  
2. Block UART / GPIO / SPI directed tests PASS  
3. Multi-seed random GPIO meets bin-diversity target  
4. Firmware demos PASS at pins  
5. Negatives in gate PASS (lockout, IDLE hold, AHB stall as present)  
6. Coverage policy documented; glue-line RTL results available  
7. Gate-level smoke PASS  
8. No expected failures in the official gate  

---

## 13. Reproduce

```bash
cd verification/cocotb
export PYTHONPATH="$(pwd):${PYTHONPATH}"

make smoke
make random
RANDOM_SEED=42 make random
make primes && make piezo && make game
make dmem
make scan-lockout
make pyuvm-regress

make -C block/gpio MODULE=test_gpio_smoke COCOTB_TEST_MODULES=test_gpio_smoke
make -C block/gpio MODULE=test_gpio_write COCOTB_TEST_MODULES=test_gpio_write
make -C block/spi  MODULE=test_spi_smoke  COCOTB_TEST_MODULES=test_spi_smoke
make -C block/spi  MODULE=test_spi_tx     COCOTB_TEST_MODULES=test_spi_tx

./run_block_regress.sh
./run_all_verify.sh
python3 merge_coverage.py

cd ../..
fusesoc run --target sim --setup --build ::pico_soc:1.0.0
bash scripts/run_honesty_freeze.sh
make gl
```

Per-run artifacts: cocotb `results.xml` in the active directory. Freeze logs via `tee` as needed.

---

## 14. Artifact index

| Artifact | Location |
|----------|----------|
| This report | `VERIFICATION.md` |
| Exit criteria | `verification/docs/VERIFICATION_GATES.md` |
| Code coverage policy | `verification/docs/CODE_COVERAGE.md` |
| Block MDV notes | `verification/docs/BLOCK_MDV.md` (if present) |
| pyuvm architecture | `verification/docs/PYUVM_ARCHITECTURE.md` (if present) |
| Requirements traceability | `REQUIREMENTS_TRACEABILITY.md` |
| Chip tests | `verification/cocotb/test_pyuvm_*.py` |
| Block tests | `verification/cocotb/block/*/test_*.py` |
| Agents / scoreboard | `verification/cocotb/tb/` |
| Coverage merge | `verification/cocotb/coverage_merge.json` |
| Verilator data | `verification/cocotb/coverage_rtl/obj_dir/coverage.dat` |
| Annotated RTL | `verification/cocotb/coverage_rtl/annotate/` |
| Freeze scripts | `run_all_verify.sh`, `run_block_regress.sh` |
| FuseSoC | `pico_soc.core` |
| Firmware | `firmware/` |
| Memory map | `memory_map.md` |
| Timing / area / pinout | `TIMING_REPORT.md`, `AREA_REPORT.md`, `PINOUT.md` |

---

*Related detail: `REQUIREMENTS_TRACEABILITY.md`, `verification/docs/VERIFICATION_GATES.md`.*
