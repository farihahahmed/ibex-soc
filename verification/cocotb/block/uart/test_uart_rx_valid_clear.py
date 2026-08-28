"""Block UART R-UART-07: STATUS read does NOT clear rx_valid; DATA read DOES.

Directly asserts the polling contract in uart.sv:
  - offset 0 (STATUS, addr[2]=0): read peeks tx_busy/rx_valid, clears nothing.
  - offset 4 (DATA,   addr[2]=1): read returns the byte AND clears rx_valid.

This closes R-UART-07 from Partial (behaviour exercised) to a direct assertion.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from tb.agents.apb import ApbItem, ApbDriver, dut_handle

BIT_CYCLES = 8
RX_VALID = 0x2  # STATUS bit1


async def uart_drive_rx(dut, byte):
    dut.rx.value = 1
    for _ in range(BIT_CYCLES):
        await RisingEdge(dut.PCLK)
    dut.rx.value = 0                       # start bit
    for _ in range(BIT_CYCLES):
        await RisingEdge(dut.PCLK)
    for i in range(8):                     # 8 data bits, LSB first
        dut.rx.value = (byte >> i) & 1
        for _ in range(BIT_CYCLES):
            await RisingEdge(dut.PCLK)
    dut.rx.value = 1                        # stop
    for _ in range(BIT_CYCLES * 2):
        await RisingEdge(dut.PCLK)


async def read_reg(drv, addr):
    it = ApbItem("rd", write=0, addr=addr, data=0)
    await drv._do_transfer(it)
    return it.rdata


@cocotb.test()
async def test_uart_rx_valid_clear(dut):
    dut_handle.DUT = dut
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.rx.value = 1
    for _ in range(4):
        await RisingEdge(dut.PCLK)
    dut.PRESETn.value = 1
    for _ in range(2):
        await RisingEdge(dut.PCLK)

    drv = ApbDriver("drv", None)
    byte = 0xA5

    # a byte arrives on RX
    await uart_drive_rx(dut, byte)

    # rx_valid must be set now
    st = await read_reg(drv, 0x0)
    assert st & RX_VALID, f"rx_valid should be set after RX, STATUS=0x{st:x}"

    # (1) repeated STATUS reads must NOT clear rx_valid — the polling case
    for i in range(3):
        st = await read_reg(drv, 0x0)
        assert st & RX_VALID, (
            f"STATUS read #{i+1} cleared rx_valid — polling would be broken "
            f"(STATUS=0x{st:x})"
        )

    # (2) DATA read returns the byte AND clears rx_valid
    data = await read_reg(drv, 0x4)
    assert (data & 0xFF) == byte, f"DATA=0x{data & 0xFF:02x}, expected 0x{byte:02x}"

    # give the clear a cycle to settle, then confirm rx_valid is now 0
    await RisingEdge(dut.PCLK)
    st = await read_reg(drv, 0x0)
    assert not (st & RX_VALID), (
        f"rx_valid should be clear after DATA read, STATUS=0x{st:x}"
    )

    # (3) a second DATA read on an empty FIFO must not re-assert rx_valid
    st = await read_reg(drv, 0x0)
    assert not (st & RX_VALID), f"rx_valid unexpectedly set again, STATUS=0x{st:x}"

    cocotb.log.info(
        "*** R-UART-07 PASS: STATUS peek preserves rx_valid; DATA read clears it ***"
    )
