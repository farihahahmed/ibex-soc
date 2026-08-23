# Pico SoC – regression status

## One-command chip regress
cd verification/cocotb
export PYTHONPATH="$(pwd):${PYTHONPATH}"
make pyuvm-regress

Includes: smoke, random GPIO/UART/SPI, UART RX e2e, primes/piezo/game,
dmem, concurrent GPIO+UART+SPI, scan corners, IDLE-RUN re-run,
illegal-addr stress, dmem byte stress, coverage-merge (19 GPIO bins).

## Block MDV
cd block/uart && make smoke tx tx-random rx
cd block/spi  && make smoke tx tx-random rx

APB VIP: ACCESS sample + protocol check (PENABLE without PSEL).

## Gates
Functional chip regress: PASS
Coverage merge unique bins >= 5: PASS (19)
UART/SPI block MDV + CR: PASS
APB protocol check: present
Glue RTL line coverage: ~70% (documented)
