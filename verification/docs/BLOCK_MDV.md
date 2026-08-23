# Block-level MDV – Pico SoC

Isolated peripheral tests: APB VIP + directed + constrained-random + scoreboard.

## Run
cd verification/cocotb
make -C block/uart block-regress
make -C block/gpio block-regress
make -C block/spi  block-regress
make -C block all
## Blocks
| Block | TOPLEVEL | Tests |
|-------|----------|--------|
| UART | apb_uart | smoke, TX, RX, random |
| GPIO | apb_gpio | smoke, write, read, random |
| SPI | apb_spi | smoke, TX, RX, tx_random, random |

## Shared VIP
tb/agents/apb/ — ApbItem, ApbDriver, ApbMonitor, ApbAgent

## Exit
All three block-regress targets PASS. Complements chip pyuvm-regress; does not replace it.

## Shared bus UVC

APB master VIP lives under `verification/cocotb/tb/agents/apb/` and is shared by UART, GPIO, and SPI block tests. See `tb/agents/README.md`.
