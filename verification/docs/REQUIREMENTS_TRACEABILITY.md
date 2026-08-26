# Pico SoC — Requirements → Tests Traceability

**Purpose:** Map each design requirement to the test(s) that prove it.  
**Rule:** A requirement is *closed* only when at least one listed test is **PASS** in the official gate (`./run_all_verify.sh` or named block target).  
**Last updated:** 2026-08-23

---

## Legend

| Tag | Meaning |
|-----|---------|
| **CHIP** | Chip-level pyuvm / cocotb (`verification/cocotb`) |
| **BLOCK** | Isolated block MDV (`verification/cocotb/block/...`) |
| **GL** | Gate-level netlist sim |
| **DIR** | Directed |
| **CR** | Constrained-random |
| **NEG** | Negative / illegal / lockout |

---

## 1. Boot, scan, and CPU control

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-BOOT-01 | Scan can load IMEM words | `test_pyuvm_smoke`, `test_pyuvm_random`, block `scan` mem | CHIP / BLOCK | DIR | Closed |
| R-BOOT-02 | FSM can enter RUN and ungates `cpu_clk` | `test_pyuvm_smoke`, block `fsm` run | CHIP / BLOCK | DIR | Closed |
| R-BOOT-03 | In IDLE, `cpu_clk` stays gated | block `fsm` idle-hold | BLOCK | NEG | Closed |
| R-BOOT-04 | COUNTDOWN mode runs then gates | block `fsm` countdown | BLOCK | DIR | Closed |
| R-BOOT-05 | While RUN, scan cannot rewrite IMEM (lockout) | `test_pyuvm_scan_lockout` (`make scan-lockout`) | CHIP | NEG | Closed |
| R-BOOT-06 | CLKGEN / scan targets decode correctly | block `scan` clkgen / fsm | BLOCK | DIR | Closed |

**Make:** `make smoke`, `make scan-lockout`, `make -C block/fsm …`, `make -C block/scan …`

---

## 2. Memory map and bus fabric

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-MAP-01 | GPIO base `0x0001_0000` is writable / readable | `test_pyuvm_smoke`, `test_pyuvm_random`, block gpio write/read | CHIP / BLOCK | DIR / CR | Closed |
| R-MAP-02 | UART base `0x0002_0000` STATUS/DATA | primes, uart RX E2E, block uart tx/rx | CHIP / BLOCK | DIR | Closed |
| R-MAP-03 | SPI base `0x0003_0000` drives serial | game, block spi tx/rx | CHIP / BLOCK | DIR | Closed |
| R-MAP-04 | AHB decode selects correct slave | block `ahb` decode | BLOCK | DIR | Closed |
| R-MAP-05 | AHB mux returns correct slave HRDATA | block `ahb` mux | BLOCK | DIR | Closed |
| R-MAP-06 | Slave HREADY low stalls master | block `ahb` hready-stall | BLOCK | NEG | Closed |
| R-MAP-07 | Illegal / unmapped address behaviour | `test_pyuvm_illegal_addr` *(if present)* | CHIP | NEG | Open / partial |
| R-MAP-08 | Concurrent multi-peripheral traffic | `test_pyuvm_concurrent` *(if present)* | CHIP | CR | Open / partial |

**Memory map source of truth:** repo root `memory_map.md`

---

## 3. GPIO

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-GPIO-01 | After reset, gpio_out is 0 | block gpio smoke | BLOCK | DIR | Closed |
| R-GPIO-02 | APB write updates gpio_out | block gpio write; chip smoke (0x05) | BLOCK / CHIP | DIR | Closed |
| R-GPIO-03 | gpio_in is readable via APB | block gpio read | BLOCK | DIR | Closed |
| R-GPIO-04 | Random legal values observed | `test_pyuvm_random`, block gpio random; multi-seed | CHIP / BLOCK | CR | Closed |
| R-GPIO-05 | Tone / toggle activity (piezo-style) | `test_pyuvm_piezo` | CHIP | DIR | Closed |

---

## 4. UART

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-UART-01 | TX idle high after reset | block uart smoke | BLOCK | DIR | Closed |
| R-UART-02 | APB write to DATA transmits byte on TX | block uart tx / tx-sb / tx-byte | BLOCK | DIR | Closed |
| R-UART-03 | Constrained-random TX bytes | block uart tx-random; chip random-uart | BLOCK / CHIP | CR | Closed |
| R-UART-04 | RX bit-bang → DATA → software path | `test_pyuvm_uart_rx_e2e` | CHIP | DIR | Closed |
| R-UART-05 | Firmware streams characters (primes) | `test_pyuvm_primes` | CHIP | DIR | Closed |
| R-UART-06 | Predictor/scoreboard matches TX byte | block uart tx-sb / regress | BLOCK | DIR | Closed |

**Registers:** STATUS `0x0002_0000` (bit0 tx_busy, bit1 rx_valid); DATA `0x0002_0004`

---

## 5. SPI

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-SPI-01 | Idle: cs_n=1, sclk quiet | block spi smoke | BLOCK | DIR | Closed |
| R-SPI-02 | APB write produces MOSI bit stream | block spi tx; chip game | BLOCK / CHIP | DIR | Closed |
| R-SPI-03 | Constrained-random TX | block / chip random-spi | BLOCK / CHIP | CR | Closed |
| R-SPI-04 | RX path (if implemented) | block spi rx | BLOCK | DIR | Closed |
| R-SPI-05 | Game firmware produces many SPI bytes | `test_pyuvm_game` | CHIP | DIR | Closed |

---

## 6. Narrow memory (IMEM / DMEM)

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-MEM-01 | Scan-loaded program is fetched and executes | smoke, primes, piezo, game | CHIP | DIR | Closed |
| R-MEM-02 | DMEM SW then LW produces expected data path | `test_pyuvm_dmem` (`make dmem`) | CHIP | DIR | Closed |
| R-MEM-03 | Stack fits in 512 B dmem (STACKADDR 0x200) | FW sizes + dmem test; firmware README | CHIP | DIR | Closed |
| R-MEM-04 | Dense byte/half/word stress | `test_pyuvm_dmem_stress` *(if present)* | CHIP | CR | Open / partial |
| R-MEM-05 | Glue RTL line coverage gate (~70% excl. CPU/SRAM) | Verilator `cov_sim` + docs | TOOL | — | Closed (narrative) |

---

## 7. Firmware demos

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-FW-01 | primes: UART prints primes | `make primes` / `test_pyuvm_primes` | CHIP | DIR | Closed |
| R-FW-02 | piezo: GPIO[0] toggles (tone) | `make piezo` / `test_pyuvm_piezo` | CHIP | DIR | Closed |
| R-FW-03 | game: SPI activity | `make game` / `test_pyuvm_game` | CHIP | DIR | Closed |
| R-FW-04 | Each binary ≤ 512 B IMEM | firmware README + build sizes | DOC | — | Closed |

---

## 8. Gate-level and physical

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-GL-01 | Post-PnR netlist smoke | `make gl` / `verification/gl` | GL | DIR | Closed |
| R-GL-02 | GL vs RTL same smoke result | *(compare logs)* | GL | DIR | Open |
| R-PD-01 | Timing report present | `TIMING_REPORT.md` | DOC | — | Closed / confirm |
| R-PD-02 | Area / pinout documented | `AREA_REPORT.md`, `PINOUT.md` | DOC | — | Closed / confirm |

---

## 9. Methodology / process requirements

| ID | Requirement | Evidence | Status |
|----|-------------|----------|--------|
| R-METH-01 | Block-level MDV for UART/GPIO/SPI | `docs/BLOCK_MDV.md`, `./run_block_regress.sh` | Closed |
| R-METH-02 | Chip pyuvm env + scoreboard + coverage | `docs/PYUVM_ARCHITECTURE.md` (if present), smoke/random | Closed |
| R-METH-03 | One-button official gate | `./run_all_verify.sh` EXIT=0 | Closed |
| R-METH-04 | FuseSoC targets sim / pyuvm / block | `fusesoc core-info ::pico_soc:1.0.0` | Closed |
| R-METH-05 | Exit criteria written | `docs/VERIFICATION_GATES.md` | Closed |
| R-METH-06 | Requirements→tests table | **this document** | Closed |
| R-METH-07 | Architecture diagram | *(next packaging item)* | Open |
| R-METH-08 | CI matrix on real runners | `.github/workflows` skeleton only | Open |

---

## Official gate mapping

| Command | Covers (examples) |
|---------|-------------------|
| `./run_block_regress.sh` | R-UART-*, R-GPIO-*, R-SPI-*, R-BOOT-03/04/06, R-MAP-04..06 |
| `./run_all_verify.sh` | Chip smoke/random/FW/dmem/scan-lockout + block + lint (+ gl if scripted) |
| `make scan-lockout` | R-BOOT-05 |
| `make dmem` | R-MEM-02 |
| `make gl` | R-GL-01 |
| `fusesoc run --target block …` | Same as block regress via FuseSoC |

---

## Open items (do not claim closed)

- R-MAP-07 illegal address (confirm test exists and is in gate)
- R-MAP-08 concurrent peripherals
- R-MEM-04 dense narrow-mem stress
- R-GL-02 GL↔RTL compare
- R-METH-07 architecture diagram
- R-METH-08 real CI runners

---

## How to maintain

1. New requirement → add row with unique `R-…` ID.  
2. New test → add to every requirement it proves.  
3. Only flip **Status** to Closed when the test is green in the official gate.  
4. Re-run `./run_all_verify.sh` before schematic / tapeout review.

---

*Canonical: `verification/docs/REQUIREMENTS_TRACEABILITY.md` (copy from artifacts if needed).*
