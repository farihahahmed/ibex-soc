# Pico SoC Verification Architecture

## Chip-level pyuvm env

uvm_test (smoke / random / primes / ...)
    |
IbexSocEnv
    |
    +-- scan_agent   (driver + sequencer)
    +-- gpio_agent   (monitor)
    +-- uart_agent   (monitor)
    +-- spi_agent    (monitor)
    +-- scoreboard + functional coverage

Stimulus: scan agent loads program and sets FSM RUN.
Check: GPIO/UART/SPI monitors feed the scoreboard.
Coverage: flow events + gpio bins; RTL glue line via Verilator.

## Block-level (UART example)

APB master VIP (driver + monitor)
    |
DUT: apb_uart / uart
    |
UART serial monitor (TX / RX)
    |
predictor  -->  scoreboard

Same pattern for GPIO and SPI blocks.

## Official regress entry points
- make pyuvm-regress   (chip + dmem)
- make gl              (gate-level smoke)
- block/uart (and gpio/spi) make targets
- make lint

See also: VERIFICATION_PLAN.md, REQUIREMENTS_TRACEABILITY.md
