# Phase 1 Status – cocotb Foundation (COMPLETE)

## Working Tests

| Test | File | What it checks | Status |
|------|------|----------------|--------|
| Directed | test_chip_basic.py | Scan → RUN → GPIO=0x05, UART=0x41, SPI=0xB7 | PASS |
| Firmware | test_primes.py | Load real primes.bin and run | PASS |

## How to run
cd verification/cocotb
source ../../.venv/bin/activate
make basic
make primes
make regress
