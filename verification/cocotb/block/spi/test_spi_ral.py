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

from tb.coverage.stress_cov import StressCoverage
_scov = StressCoverage()
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

    _scov.hit("spi","busy_handshake"); _scov.hit("spi","rx_all_ones"); _scov.hit("spi","rx_all_zeros")
    cocotb.log.info("*** SPI RAL busy+rx PASS ***")


async def drive_miso_pattern(dut, byte):
    """Follow SCLK and present MISO MSB-first so the master samples `byte`.
    Mode 0: master samples on SCLK rising edge; present each bit while SCLK low."""
    for i in range(7, -1, -1):
        # wait for SCLK low (setup window), drive the bit
        while int(dut.sclk.value) != 0:
            await RisingEdge(dut.PCLK)
        dut.miso.value = (byte >> i) & 1
        # wait for the rising edge (master samples), then for it to pass
        while int(dut.sclk.value) != 1:
            await RisingEdge(dut.PCLK)


@cocotb.test()
async def test_spi_ral_miso_pattern(dut):
    """Real per-bit RX: a slave model drives 0xA5 MSB-first against SCLK;
    the RAL rx field must read back exactly 0xA5."""
    await reset(dut)
    slave = cocotb.start_soon(drive_miso_pattern(dut, 0xA5))
    await apb_write(dut, spi.ctrl.offset, spi.ctrl.encode(tx=0x00))
    for _ in range(400):
        st = await apb_read(dut, spi.ctrl.offset)
        if spi.ctrl.field("busy", st) == 0:
            break
    rx = spi.ctrl.field("rx", st)
    assert rx == 0xA5, f"per-bit MISO: rx=0x{rx:02x}, want 0xA5"
    _scov.hit("spi","rx_bit_pattern")
    cocotb.log.info("*** SPI per-bit MISO pattern PASS ***")


@cocotb.test()
async def test_spi_write_while_busy_ignored(dut):
    """A write during an active transfer must not corrupt it: RTL ignores
    writes while state != IDLE (documents as-built behavior)."""
    await reset(dut)
    dut.miso.value = 1
    await apb_write(dut, spi.ctrl.offset, spi.ctrl.encode(tx=0x55))
    st = await apb_read(dut, spi.ctrl.offset)
    assert spi.ctrl.field("busy", st) == 1
    # mid-transfer write attempt
    await apb_write(dut, spi.ctrl.offset, spi.ctrl.encode(tx=0xFF))
    for _ in range(400):
        st = await apb_read(dut, spi.ctrl.offset)
        if spi.ctrl.field("busy", st) == 0:
            break
    assert spi.ctrl.field("busy", st) == 0, "transfer must still complete"
    assert spi.ctrl.field("rx", st) == 0xFF, "miso high -> rx 0xFF (transfer intact)"
    # and no second transfer must have auto-started
    st = await apb_read(dut, spi.ctrl.offset)
    assert spi.ctrl.field("busy", st) == 0, "ignored write must not queue a transfer"
    _scov.hit("spi","write_while_busy")
    cocotb.log.info("*** SPI write-while-busy ignored (documented) PASS ***")


@cocotb.test()
async def test_spi_back_to_back_transfers(dut):
    """Three transfers driven straight off the busy handshake with alternating
    MISO levels: each must complete independently with the right RX byte."""
    await reset(dut)
    for tx, miso, exp in ((0x11, 1, 0xFF), (0x22, 0, 0x00), (0x33, 1, 0xFF)):
        rx = await xfer(dut, tx, miso_level=miso)
        assert rx == exp, f"b2b transfer tx=0x{tx:02x}: rx=0x{rx:02x}, want 0x{exp:02x}"
    cocotb.log.info("*** SPI back-to-back transfers PASS ***")
