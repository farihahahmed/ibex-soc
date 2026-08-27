"""UART block test driven through the register-abstraction layer.

Every bit position comes from tb.reg_model.soc_regs -- this test never
hardcodes a shift or mask. If the RTL layout changes, soc_regs changes and
this test follows automatically. That single-source-of-truth property is the
whole point of the RAL, and this test is what proves the model matches the DUT.

DUT: rtl/apb_uart.sv (block Makefile: CLK_FREQ=8, BAUD_RATE=1 -> 8 cyc/bit).
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tb.reg_model.soc_regs import uart

BIT_CYCLES = 8


async def reset(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.rx.value = 1
    await Timer(50, unit="ns")
    dut.PRESETn.value = 1
    for _ in range(5):
        await RisingEdge(dut.PCLK)


async def apb_write(dut, addr, data):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1; dut.PWRITE.value = 1
    dut.PADDR.value = addr; dut.PWDATA.value = data
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    while int(dut.PREADY.value) == 0:
        await RisingEdge(dut.PCLK)
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0; dut.PENABLE.value = 0; dut.PWRITE.value = 0


async def apb_read(dut, addr):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1; dut.PWRITE.value = 0
    dut.PADDR.value = addr; dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    while int(dut.PREADY.value) == 0:
        await RisingEdge(dut.PCLK)
    val = int(dut.PRDATA.value)
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0; dut.PENABLE.value = 0
    return val


@cocotb.test()
async def test_uart_ral_tx_busy(dut):
    """Transmit a byte via the DATA reg model; track tx_busy via the STATUS model."""
    await reset(dut)

    # STATUS decoded through the model -- idle: not busy
    st = await apb_read(dut, uart.status.offset)
    uart.status.check(st, tx_busy=0)
    cocotb.log.info(f"idle STATUS: {uart.status.decode(st)}")

    # Kick a transmit by writing the DATA register's TX field via the model.
    word = uart.data.encode(tx=0x41)          # 'A' -- no hardcoded shift here
    await apb_write(dut, uart.data.offset, word)

    # STATUS.tx_busy (position from the model) must now report the transmit.
    st = await apb_read(dut, uart.status.offset)
    assert uart.status.field("tx_busy", st) == 1, \
        f"expected tx_busy after write; got {uart.status.decode(st)}"
    cocotb.log.info(f"mid-TX STATUS: {uart.status.decode(st)}")

    # Let the frame shift out (start+8+stop bits), then it must clear.
    for _ in range(BIT_CYCLES * 12):
        await RisingEdge(dut.PCLK)
    st = await apb_read(dut, uart.status.offset)
    uart.status.check(st, tx_busy=0)
    cocotb.log.info(f"post-TX STATUS: {uart.status.decode(st)}")

    cocotb.log.info("*** UART RAL tx_busy PASS ***")
