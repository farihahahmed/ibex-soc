# How to run Pico SoC verification

export PYTHONPATH="/foss/designs/ibex_soc/verification/cocotb:\${PYTHONPATH}"

## Chip-level
cd verification/cocotb
make smoke
make random
make primes
make piezo
make game
make dmem
make pyuvm-regress

## Block-level
cd block/uart && make uart-block
cd ../gpio && make gpio-block
cd ../spi && make spi-block

## Official gate
1. make pyuvm-regress
2. uart-block / gpio-block / spi-block


## Gate-level
See GATE_LEVEL.md (netlist: gds/chip_top_full.pnl.v).
