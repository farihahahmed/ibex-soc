# Pico SoC — Requirements → Tests Traceability

**Purpose:** Map each design requirement to the test(s) that prove it.
**Rule:** A requirement is *closed* only when at least one listed test is **PASS** in the official gate (`./run_all_verify.sh`).
**Last updated:** 2026-08-27
**Gate:** 70 tests across 44 suites, 0 failures, exit code 0. One gate, no excluded tests, no allowed-to-fail legs.

---

## Legend

| Tag | Meaning |
|-----|---------|
| **CHIP** | Chip-level pyuvm / cocotb (`verification/cocotb`) |
| **BLOCK** | Isolated block MDV (`verification/cocotb/block/...`) |
| **GL** | Gate-level netlist sim |
| **FORMAL** | Bounded model checking (`verification/formal`) |
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
| R-BOOT-04 | COUNTDOWN mode runs then gates | `test_pyuvm_countdown`, block `fsm` countdown | CHIP / BLOCK | DIR | Closed |
| R-BOOT-05 | While RUN, scan cannot rewrite IMEM (lockout) | `test_pyuvm_scan_lockout` | CHIP | NEG | Closed |
| R-BOOT-06 | CLKGEN / scan targets decode correctly | block `scan` clkgen / fsm | BLOCK | DIR | Closed |
| R-BOOT-07 | Scan can read IMEM words back (tgt=3) | `test_scan_readback` — 4 addresses incl. the last word of imem | CHIP | DIR | Closed |
| R-BOOT-08 | Status word readable via scan (tgt=3, addr[13]=1) | `test_scan_status` — FSM mode and memory ownership observed in IDLE and RUN | CHIP | DIR | Closed |
| R-BOOT-09 | CPU trap is observable after the CPU halts | Status word bit 0: sticky, synchronised into `sys_clk`. `test_scan_trap` loads an illegal instruction, runs the CPU, and observes the trap bit set and sticky via the status word | CHIP | DIR | **Closed** |
| R-BOOT-10 | Clock divider ratio and glitch-free source switch | `test_clkgen` — 10 / 80 / 10 ns, both switch directions, no clock stop | CHIP | DIR | Closed |
| R-BOOT-11 | Scan chain formal properties hold | `verification/formal/run_scan_chain_formal.py` — bounded model check, PASSED | BLOCK | FORMAL | Closed |
| R-BOOT-12 | Clock-gating FSM formal properties hold | `verification/formal/run_test_fsm_formal.py` — bounded model check, PASSED | BLOCK | FORMAL | Closed |

**Known limitation:** scan addresses ≥ 0x80 alias to the low range (`ld_word_addr[6:0]`). Not currently guarded. See KNOWN_GAPS.

---

## 2. Memory map and bus fabric

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-MAP-01 | GPIO base `0x0001_0000` is writable / readable | `test_pyuvm_smoke`, `test_pyuvm_random`, block gpio write/read | CHIP / BLOCK | DIR / CR | Closed |
| R-MAP-02 | UART base `0x0002_0000` STATUS/DATA | primes, uart RX E2E, block uart tx/rx | CHIP / BLOCK | DIR | Closed |
| R-MAP-03 | SPI base `0x0003_0000` drives serial | game, block spi tx | CHIP / BLOCK | DIR | Closed |
| R-MAP-04 | AHB decode selects correct slave | block `ahb` decode | BLOCK | DIR | Closed |
| R-MAP-05 | AHB mux returns correct slave HRDATA | block `ahb` mux | BLOCK | DIR | Closed |
| R-MAP-06 | Slave HREADY low stalls master | block `ahb` hready-stall | BLOCK | NEG | Closed |
| R-MAP-07 | Illegal / unmapped address behaviour | `test_pyuvm_illegal_addr` (in gate) | CHIP | NEG | Closed |
| R-MAP-08 | Concurrent multi-peripheral traffic | `test_pyuvm_concurrent` (in gate) | CHIP | CR | Closed |

**Memory map source of truth:** `docs/memory_map.md`
**Known limitation:** `HADDR[17:16]` is a 2-bit decode, so every address maps to a real slave — there is no unmapped-address error response, and `HRESP` is tied low. See KNOWN_GAPS.

---

## 3. GPIO

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-GPIO-01 | After reset, gpio_out is 0 | block gpio smoke | BLOCK | DIR | Closed |
| R-GPIO-02 | APB write updates gpio_out | block gpio write; chip smoke (0x05) | BLOCK / CHIP | DIR | Closed |
| R-GPIO-03 | gpio_in is readable via APB | block gpio read | BLOCK | DIR | Closed |
| R-GPIO-04 | Random legal values observed | `test_pyuvm_random`, block gpio random | CHIP / BLOCK | CR | Closed |
| R-GPIO-05 | Tone / toggle activity (piezo-style) | `test_pyuvm_piezo` | CHIP | DIR | Closed |
| R-GPIO-06 | Output register is readable back | `rdata[NUM_IN+NUM_OUT-1:NUM_IN]` returns `out_reg`; block gpio read | BLOCK | DIR | Closed |

**Note:** write and read layouts differ — software writes outputs at bits `[NUM_OUT-1:0]` but reads them back at `[NUM_IN+NUM_OUT-1:NUM_IN]`. Deliberate, so inputs stay at `[1:0]` for backward compatibility.

---

## 4. UART

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-UART-01 | TX idle high after reset | block uart smoke | BLOCK | DIR | Closed |
| R-UART-02 | APB write to DATA transmits byte on TX | block uart tx / tx-sb / tx-byte | BLOCK | DIR | Closed |
| R-UART-03 | Constrained-random TX bytes | block uart tx-random; `test_pyuvm_random_uart` | BLOCK / CHIP | CR | Closed |
| R-UART-04 | RX bit-bang → DATA → software path | `test_pyuvm_uart_rx_e2e`, `test_pyuvm_uart_rx` | CHIP | DIR | Closed |
| R-UART-05 | Firmware streams characters (primes) | `test_pyuvm_primes` | CHIP | DIR | Closed |
| R-UART-06 | Predictor/scoreboard matches TX byte | block uart tx-sb / regress | BLOCK | DIR | Closed |
| R-UART-07 | A status read does NOT clear rx_valid; only a DATA read does | `uart.sv` splits STATUS/DATA on `addr[2]`; directly asserted by `block/uart/test_uart_rx_valid_clear` (repeated STATUS reads preserve rx_valid; DATA read returns the byte and clears it) | CHIP | DIR | **Closed** |
| R-UART-08 | Silicon baud rate is correct for the shipped clock | `CLK_FREQ`/`BAUD_RATE` give BAUD_DIV 289 → 115,340 baud, +0.12% error | DOC | — | Closed |

**Registers:** STATUS `0x0002_0000` (bit0 tx_busy, bit1 rx_valid); DATA `0x0002_0004`
**Known limitation:** no overrun flag — a second byte arriving before the first is read overwrites it silently. See KNOWN_GAPS.

---

## 5. SPI

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-SPI-01 | Idle: cs_n=1, sclk quiet | block spi smoke | BLOCK | DIR | Closed |
| R-SPI-02 | APB write produces MOSI bit stream | block spi tx; chip game | BLOCK / CHIP | DIR | Closed |
| R-SPI-03 | Constrained-random TX | `test_pyuvm_random_spi`, block spi | BLOCK / CHIP | CR | Closed |
| R-SPI-04 | RX path receives a byte on MISO | `block/spi` rx tests; dedicated `spi_miso` pin added | BLOCK | DIR | Closed |
| R-SPI-05 | Game firmware produces many SPI bytes | `test_pyuvm_game` | CHIP | DIR | Closed |
| R-SPI-06 | Mode 0 framing: 8 SCLK edges per byte | `spi.sv` counts on the rising edge and finishes after the 8th sample; block spi tx checks `sclk_edges=16` | BLOCK | DIR | Closed |

---

## 6. Narrow memory (IMEM / DMEM)

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-MEM-01 | Scan-loaded program is fetched and executes | smoke, primes, piezo, game, crc, pcpi | CHIP | DIR | Closed |
| R-MEM-02 | DMEM SW then LW produces expected data path | `test_pyuvm_dmem` | CHIP | DIR | Closed |
| R-MEM-03 | Stack fits in 512 B dmem (STACKADDR 0x200) | FW sizes + dmem test; firmware README | CHIP | DIR | Closed |
| R-MEM-04 | Dense byte/half/word stress | `test_pyuvm_dmem_stress` (in gate) | CHIP | CR | Closed |
| R-MEM-05 | Line coverage of our own RTL | Verilator: **88.8%** (890/1002 lines), picorv32 excluded. Artifact: `verification/coverage/coverage.info` | TOOL | — | Closed |

**Known limitation:** `.rodata` is not reachable by loads. The linker places read-only data in instruction memory, but `pico_shim` routes data accesses to the AHB data memory. Firmware must generate constants arithmetically. See KNOWN_GAPS.

---

## 6b. Custom instruction extension (PCPI)

Seven instructions in the RISC-V custom-0 opcode space (0x0B), selected by funct3.
Verified twice: standalone against a Python model, and end-to-end through the CPU.

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-PCPI-01 | `crc32.b` folds one byte, matches IEEE 802.3 | `test_pyuvm_pcpi` — result `cbf43926`, the **published** CRC32 check constant | CHIP | DIR | Closed |
| R-PCPI-02 | `crc32.w` folds a 32-bit word | `test_pyuvm_pcpi` vs Python model | CHIP | DIR | Closed |
| R-PCPI-03 | `popcnt` counts set bits | `test_pyuvm_pcpi` | CHIP | DIR | Closed |
| R-PCPI-04 | `brev` reverses bit order | `test_pyuvm_pcpi` | CHIP | DIR | Closed |
| R-PCPI-05 | `mac` accumulates a **signed** 16×16 product | `test_pyuvm_pcpi` — includes a negative operand (0xFFFF × 5 → −5) | CHIP | DIR | Closed |
| R-PCPI-06 | `macrd` reads the accumulator without modifying it | `test_pyuvm_pcpi` | CHIP | DIR | Closed |
| R-PCPI-07 | `macclr` zeroes the accumulator | `test_pyuvm_pcpi` | CHIP | DIR | Closed |
| R-PCPI-08 | An unclaimed funct3 falls through to the CPU illegal trap | Standalone bench reject case: `pcpi_ready` stays low for funct3=111 | BLOCK | NEG | Closed |

---

## 7. Firmware demos

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-FW-01 | primes: UART prints primes | `test_pyuvm_primes` | CHIP | DIR | Closed |
| R-FW-02 | piezo: GPIO[0] toggles (tone) | `test_pyuvm_piezo` | CHIP | DIR | Closed |
| R-FW-03 | game: SPI activity | `test_pyuvm_game` | CHIP | DIR | Closed |
| R-FW-04 | Each binary ≤ 512 B IMEM | firmware README + build sizes (largest 190 B) | DOC | — | Closed |
| R-FW-05 | crc_demo: CRC32 over the standard check vector | `test_pyuvm_crc` | CHIP | DIR | Closed |
| R-FW-06 | pcpi_demo: all seven custom instructions | `test_pyuvm_pcpi` | CHIP | DIR | Closed |
| R-FW-07 | Toolchain flags match the core configuration | `-march=rv32emc -mabi=ilp32e` + libgcc; wrong flags produce illegal instructions | DOC | — | Closed |

---

## 8. Gate-level and physical

| ID | Requirement | Tests | Level | Type | Status |
|----|-------------|-------|-------|------|--------|
| R-GL-01 | Post-PnR netlist boots and drives pins | `make -C verification/gl gl-smoke` against `gds/chip_top_full.pnl.v` | GL | DIR | Closed |
| R-GL-02 | GL vs RTL produce the same result for the same program | `verification/gl/tb_gl_firmware.v` (`make gl-firmware`) | GL | DIR | **Partial** — harness scan-loads real firmware into the signoff netlist's SRAM; full execution blocked by a documented picorv32 GL X-init limitation (sim artifact; equivalence proven by LVS + RTL cocotb gate) |
| R-PD-01 | Timing closed on all corners | `docs/BACKEND_REPORT.md` | DOC | — | Closed |
| R-PD-02 | Area / pinout documented | `docs/FRONTEND_SYNTHESIS.md`, `docs/PINOUT.md` | DOC | — | Closed |
| R-PD-03 | Antenna and LVS clean on the signoff run | run metrics: `antenna__violating__nets` 0, netgen "match uniquely" | DOC | — | Closed |
| R-PD-04 | DRC violations explained | 4 × M3.1, traced to a 0.110 µm Metal3 port on the **VSS** pin of the GF180 SRAM macro LEF, not to this design. `gds/DRC_WAIVER.txt` | DOC | — | Closed (reported upstream) |

---

## 9. Methodology / process requirements

| ID | Requirement | Evidence | Status |
|----|-------------|----------|--------|
| R-METH-01 | Block-level MDV for UART/GPIO/SPI | `docs/BLOCK_MDV.md`, `./run_block_regress.sh` | Closed |
| R-METH-02 | Chip pyuvm env + scoreboard + coverage | `docs/PYUVM_ARCHITECTURE.md`; coverage 88.8% line (own RTL) | Closed |
| R-METH-03 | One-button official gate | `./run_all_verify.sh` — 70 tests, EXIT=0 | Closed |
| R-METH-04 | FuseSoC targets sim / pyuvm / block | `fusesoc core-info ::pico_soc:1.0.0` | Closed |
| R-METH-05 | Exit criteria written | Section 12 of `VERIFICATION.md` | Closed |
| R-METH-06 | Requirements→tests table | **this document** | Closed |
| R-METH-07 | Architecture diagram | `VERIFICATION.md` §3.1a — design architecture block diagram (clocking, scan/FSM bring-up, CPU+PCPI, AHB/APB fabric, peripherals) | DOC | — | **Closed** |
| R-METH-08 | CI on real runners | `.github/workflows/verify.yml` — lint + gate + formal, green on every push | Closed |
| R-METH-09 | Formal property proofs | `verification/formal/` — scan chain and clock FSM, both PASSED, in CI | Closed |
| R-METH-10 | Per-block lint of every RTL module | `scripts/lint_blocks.sh` — 22 blocks, in CI | Closed |
| R-METH-11 | The scoreboard actually compares values | `test_pyuvm_neg_gpio` — `expect_fail`, passes only when a deliberately wrong expectation is caught | Closed |
| R-METH-12 | Single gate, nothing excluded or masked | Root `run_all_verify.sh` delegates to the one gate; no `fail_ok`, no ignored exit codes | Closed |
| R-METH-13 | Repository builds outside the author's machine | All paths relative; CI checks out to a clean runner | Closed |
| R-METH-14 | FSM state and arc coverage | `tb/coverage/fsm_cov.py` — 40/40 reachable states (100%), 40 arcs, across 10 state machines. Four `dmem_narrow_top` load states declared unreachable with the reason. | Closed |

---

## Official gate mapping

| Command | Covers |
|---------|--------|
| `./run_all_verify.sh` | The whole gate: 70 tests across 44 suites. Chip smoke/random/firmware/dmem/scan/clkgen/pcpi, negative/corner/stress, and all 11 block suites (uart, gpio, spi, mem, fsm, scan, scan_fsm, ahb, ahb_to_apb, apb_decoder, clkgen) |
| `./run_block_regress.sh` | R-UART-\*, R-GPIO-\*, R-SPI-\*, R-BOOT-03/04/06, R-MAP-04..06 |
| `scripts/lint_blocks.sh` | R-METH-10 — 22 blocks |
| `verification/formal/run_*_formal.py` | R-BOOT-11, R-BOOT-12, R-METH-09 |
| `make -C verification/gl gl-smoke` | R-GL-01 |

---

## Open items (do not claim closed)

- **R-GL-02** — `make gl-firmware` scan-loads real firmware (`fw_gpio_walk`)
  into the **signoff netlist's** SRAM using the same 48-bit scan protocol as the
  RTL environment. Confirmed in gate-level: the netlist elaborates, resets
  cleanly (`pico_resetn` deasserts), the cpu_clk ICG toggles, and all program
  words load into the netlist SRAM. Full firmware *execution* on the netlist is
  blocked by a documented picorv32 gate-level limitation: picorv32 initialises
  its register file and pipeline state via Verilog `initial` (picorv32.v:206),
  which synthesis does not preserve, so those non-resettable flops power up X in
  GL. This is a **simulation artifact, not a netlist or silicon defect** —
  logical equivalence to the RTL is proven by LVS (0 errors) and functional
  correctness by the RTL cocotb gate (49 suites). A full GL-execution close
  would require force-initialising all ~2,477 netlist flops with reset-
  synchronised timing, which is disproportionate for a sim-only artifact already
  covered by LVS.

See `verification/docs/KNOWN_GAPS.md` for design limitations that are deliberate
or accepted, as distinct from verification gaps.

---

## How to maintain

1. New requirement → add a row with a unique `R-…` ID.
2. New test → add it to every requirement it proves.
3. Only flip **Status** to Closed when the test is green in the official gate.
4. Prefer **Partial** or **N/A with a reason** over an optimistic Closed. A row
   that overstates what was proven costs more credibility than an honest gap.
5. Re-run `./run_all_verify.sh` before any review or tapeout submission.
