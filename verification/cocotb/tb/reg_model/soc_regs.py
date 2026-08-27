"""pico-soc peripheral register map -- the single source of truth.

Every field here mirrors the RTL exactly; the reference line is cited so a
future RTL edit has an obvious counterpart to update:

  UART  rtl/uart.sv     STATUS peek (offset 0), DATA tx/rx (offset 4, addr[2])
  SPI   rtl/spi.sv      rdata = {16'b0, rx_data[7:0], 7'b0, busy}
  GPIO  rtl/gpio.sv     rdata = {reserved, out_reg, sync2(inputs)}

Addresses are peripheral-local offsets (APB PADDR low bits); the region base
(GPIO 0x0001_0000 / UART 0x0002_0000 / SPI 0x0003_0000) is in memory_map.md.
"""
from .regs import Field, Register, RegBlock

# ---------------------------------------------------------------------------
# UART  (rtl/uart.sv)
#   STATUS @0 : bit0 tx_busy (RO), bit1 rx_valid (RO) -- read PEEKS, no clear
#   DATA   @4 : write = TX byte (WO, starts a transmit)
#               read  = RX byte (RO) and clears rx_valid (RC side effect)
UART_STATUS_OFF = 0x0
UART_DATA_OFF = 0x4

uart = RegBlock("uart", [
    Register("status", UART_STATUS_OFF,
             rfields=[
                 Field("tx_busy",  0, 1, "RO"),
                 Field("rx_valid", 1, 1, "RO"),
             ],
             wfields=[]),                       # STATUS is not written
    Register("data", UART_DATA_OFF,
             wfields=[Field("tx", 0, 8, "WO")],           # write view: TX byte
             rfields=[Field("rx", 0, 8, "RC")]),          # read view: RX byte (+clears rx_valid)
])

# ---------------------------------------------------------------------------
# SPI  (rtl/spi.sv)  -- single register, address ignored
#   write : wdata[7:0] = TX byte (WO), starts a transfer (one-shot)
#   read  : bit0 = busy (RO), bits[15:8] = last RX byte (RO)
spi = RegBlock("spi", [
    Register("ctrl", 0x0,
             wfields=[Field("tx", 0, 8, "W1P")],          # write byte -> load+start
             rfields=[
                 Field("busy", 0, 1, "RO"),
                 Field("rx",   8, 8, "RO"),
             ]),
])

# ---------------------------------------------------------------------------
# GPIO  (rtl/gpio.sv, NUM_OUT / NUM_IN parameterised) -- single reg, addr ignored
#   write : wdata[NUM_OUT-1:0] -> out_reg (RW)
#   read  : [NUM_IN-1:0]                 = synchronised input pins (RO)
#           [NUM_IN+NUM_OUT-1 : NUM_IN]  = out_reg readback (RO)
def make_gpio(num_out=5, num_in=2):
    return RegBlock("gpio", [
        Register("io", 0x0,
                 wfields=[Field("out", 0, num_out, "RW")],           # write drives outputs
                 rfields=[
                     Field("inputs",   0,       num_in,  "RO"),      # low bits = inputs
                     Field("out_rdbk", num_in,  num_out, "RO"),      # then output readback
                 ]),
    ])

# default chip config (chip_top_full: NUM_OUT=5, NUM_IN=2)
gpio = make_gpio(5, 2)


if __name__ == "__main__":
    # Self-test: exercise encode/field/decode/check against the documented RTL.
    # UART STATUS
    w = (1 << 1) | (1 << 0)          # rx_valid=1, tx_busy=1
    assert uart.status.field("tx_busy", w) == 1
    assert uart.status.field("rx_valid", w) == 1
    uart.status.check(w, tx_busy=1, rx_valid=1)

    # UART DATA: write view encodes TX; read view decodes RX
    assert uart.data.encode(tx=0x41) == 0x41
    assert uart.data.field("rx", 0x00000041) == 0x41

    # SPI: read busy + rx byte out of one word
    word = (0x5A << 8) | 1           # rx=0x5A, busy=1
    spi.ctrl.check(word, busy=1, rx=0x5A)
    assert spi.ctrl.encode(tx=0xB7) == 0xB7

    # GPIO: out readback sits above the input bits
    g = make_gpio(num_out=5, num_in=2)
    rd = (0b10101 << 2) | 0b11       # out_rdbk=0x15, inputs=0x3
    g.io.check(rd, inputs=0b11, out_rdbk=0b10101)
    assert g.io.encode(out=0b10101) == 0b10101

    print("REG-MODEL SELF-TEST PASS")
    for blk in (uart, spi, gpio):
        for r in blk.regs.values():
            print(f"  {blk.name}.{r.name} @0x{r.offset:x}: "
                  f"W[{','.join(r.wfields)}]  R[{','.join(r.rfields)}]")
