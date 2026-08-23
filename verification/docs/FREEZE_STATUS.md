# Verification freeze status

## Green
- Chip pyuvm (smoke, random, primes, piezo, game, dmem, uart rx e2e)
- Block UART / GPIO / SPI (make *-block in each block/)
- GL smoke (Ibex-era netlist; re-point after Pico PnR)
- Plan: verification/docs/PICO_SOC_VERIFICATION_PLAN.md

## Out of freeze scope
- Pico post-route GL full regress
- Formal / commercial UVM-SV

## Health check
  cd verification/cocotb && export PYTHONPATH=$(pwd):$PYTHONPATH
  make smoke
  make -C block/uart smoke
  make -C block/gpio smoke
  make -C block/spi smoke
