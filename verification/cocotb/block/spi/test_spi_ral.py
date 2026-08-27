"""SPI block test through the register model (tb.reg_model.soc_regs.spi).

Proves the RAL layout matches the DUT: write TX field -> busy asserts;
after the transfer, busy clears and the RX field holds the MISO byte.
DUT: apb_spi (loopback via miso driven from monitor of mosi not available
at block level, so drive miso constant-high -> RX = 0xFF, then constant-low
-> RX = 0x00; proves rx field position without an SPI slave model).
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tb.reg_model.soc_regs import spi


async def reset(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.miso.value = 0
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


async def xfer(dut, tx, miso_level):
    dut.miso.value = miso_level
    await apb_write(dut, spi.ctrl.offset, spi.ctrl.encode(tx=tx))
    st = await apb_read(dut, spi.ctrl.offset)
    assert spi.ctrl.field("busy", st) == 1, \
        f"busy must assert after TX write; {spi.ctrl.decode(st)}"
    for _ in range(400):
        st = await apb_read(dut, spi.ctrl.offset)
        if spi.ctrl.field("busy", st) == 0:
            return spi.ctrl.field("rx", st)
    raise AssertionError("busy never cleared")


@cocotb.test()
async def test_spi_ral_busy_and_rx(dut):
    await reset(dut)
    st = await apb_read(dut, spi.ctrl.offset)
    assert spi.ctrl.field("busy", st) == 0, "idle: busy must be 0"

    rx = await xfer(dut, 0xB7, miso_level=1)
    assert rx == 0xFF, f"miso held high: rx=0x{rx:02x}, want 0xFF"

    rx = await xfer(dut, 0x3C, miso_level=0)
    assert rx == 0x00, f"miso held low: rx=0x{rx:02x}, want 0x00"

    cocotb.log.info("*** SPI RAL busy+rx PASS ***")
