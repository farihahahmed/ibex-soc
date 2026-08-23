"""Block SPI loopback: TX byte, miso mirrors mosi, APB read sees RX byte."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def apb_write(dut, data):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1
    dut.PWRITE.value = 1
    dut.PADDR.value = 0
    dut.PWDATA.value = data & 0xFF
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0

async def apb_read(dut):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await RisingEdge(dut.PCLK)
    rdata = int(dut.PRDATA.value)
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    return rdata

@cocotb.test()
async def test_spi_loopback(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.miso.value = 0

    for _ in range(5):
        await RisingEdge(dut.PCLK)
    dut.PRESETn.value = 1
    for _ in range(3):
        await RisingEdge(dut.PCLK)

    tx_byte = 0x5A
    # Mirror MOSI onto MISO each PCLK (Mode 0: sample MISO on rising SCLK)
    async def mirror():
        while True:
            await RisingEdge(dut.PCLK)
            dut.miso.value = int(dut.mosi.value)

    cocotb.start_soon(mirror())
    await apb_write(dut, tx_byte)

    # Wait until not busy (bit0 of read)
    for _ in range(200):
        r = await apb_read(dut)
        if (r & 1) == 0:
            break
        await RisingEdge(dut.PCLK)

    r = await apb_read(dut)
    rx = (r >> 8) & 0xFF
    cocotb.log.info(f"TX=0x{tx_byte:02x}  PRDATA=0x{r:04x}  RX=0x{rx:02x}")
    assert rx == tx_byte, f"loopback expected 0x{tx_byte:02x}, got 0x{rx:02x}"
    cocotb.log.info("*** SPI loopback PASS ***")
