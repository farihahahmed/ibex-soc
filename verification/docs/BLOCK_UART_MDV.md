# Block UART MDV (match/beat Grouper methodology)

Location: verification/cocotb/block/uart

Run:
  cd verification/cocotb/block/uart
  make block-regress

Coverage of methodology:
- Isolated DUT: apb_uart + uart (no full SoC)
- APB agent (driver/monitor/item)
- Directed TX/RX
- Constrained-random TX bytes
- Bit-level TX scoreboard
