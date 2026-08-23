# Phase 6 – Firmware Self-Checking (COMPLETE)

## Tests

| Target | File | Check | Status |
|--------|------|-------|--------|
| Directed | test_chip_basic.py | GPIO=0x05, UART=0x41, SPI=0xB7 | PASS |
| primes | test_primes.py | UART prints `2 3 5 7 ...` | PASS |
| piezo_tune | test_piezo.py | GPIO[0] toggles (≥2) | PASS |
| game | test_game.py | SPI SCLK activity | PASS |
| random | test_random.py | Constrained-random GPIO | PASS |

## How to run
```bash
cd verification/cocotb
source ../../.venv/bin/activate

make basic
make primes
make piezo
make game
make random
make regress          # all of the above
make random-seeds     # multi-seed random
