# Pico SoC Verification Plan

## Scope
- DUT: `chip_top_full` (PicoRV32 + scan + AHB/APB + GPIO/UART/SPI + narrow imem/dmem)
- Levels: **block MDV** and **chip-level pyuvm**

## Methodology
- cocotb + pyuvm agents/monitors/scoreboard
- Directed + constrained-random
- Functional coverage (flow events, GPIO bins); RTL line coverage secondary (Verilator)

## Block MDV (must pass)
Command: `cd verification/cocotb && ./run_block_regress.sh` → EXIT 0

| IP | Directed proof |
|----|----------------|
| apb_uart | TX + RX + random TX |
| apb_spi | TX + RX + random TX |
| apb_gpio | write + read |
| scan_chain | mem / FSM / clkgen frames |
| ahb_interconnect | decode + response mux |
| test_fsm | IDLE / RUN / COUNTDOWN |

## Chip-level (must pass)
Command: `cd verification/cocotb && make pyuvm-regress` (and `make dmem`)

| Test | Proof |
|------|--------|
| smoke | scan-load + RUN + GPIO=0x05 |
| random | multi-seed GPIO bins |
| primes | UART primes stream |
| piezo | GPIO tone activity |
| game | SPI traffic |
| dmem | SW/LW path |
| uart_rx_e2e | bit-bang RX → FW → GPIO |

## Exit criteria (tapeout gate)
1. Block regress EXIT 0  
2. Chip pyuvm-regress + dmem PASS  
3. Functional coverage: required flow events hit; ≥5 distinct GPIO bins across seeds  
4. No known open bugs in directed paths above  

## Out of scope / secondary
- Full picorv32 toggle %  
- Formal property proofs  
