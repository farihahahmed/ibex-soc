# pyuvm Verification Architecture

## Structure

    verification/cocotb/
      tb/
        agents/
          scan/     # active: driver + sequencer
          gpio/     # passive monitor
          uart/     # passive monitor
          spi/      # passive monitor
        sequences/  # LoadProgram, StartCpu, RandomGpio, Firmware
        coverage/   # coverpoints + goals
        scoreboard.py
        env.py
      test_pyuvm_*.py

## How to run

    cd verification/cocotb
    source ../../.venv/bin/activate
    export PYTHONPATH=$(pwd)

    make smoke          # directed GPIO+UART
    make random         # constrained-random GPIO
    make primes         # primes.bin via scan agent
    make game           # game.bin SPI activity
    make pyuvm-regress  # all of the above
    ./run_pyuvm_random_seeds.sh

## Compared to first-pass cocotb

- Transactions + sequences (not bit-bang in tests)
- Agents + analysis ports + scoreboard
- Coverage with goals
- Firmwares on the same path
