"""SPI block MDV RX: drive MISO during transfer, read back via APB."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

async def apb_write(dut, data):
    await RisingEdge(dut.PCLK)
    dut.PADDR.value = 0
    dut.PWDATA.value = data
    dut.PWRITE.value = 1
    dut.PSEL.value = 1
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0

async def apb_read(dut):
    await RisingEdge(dut.PCLK)
    dut.PADDR.value = 0
    dut.PWRITE.value = 0
    dut.PSEL.value = 1
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await RisingEdge(dut.PCLK)
    val = int(dut.PRDATA.value)
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    return val

async def drive_miso_byte(dut, byte):
    """Mode 0: present bit before rising SCLK (MSB first)."""
    while int(dut.cs_n.value) == 1:
        await RisingEdge(dut.PCLK)
    for i in range(8):
        bit = (byte >> (7 - i)) & 1
        dut.miso.value = bit
        await RisingEdge(dut.sclk)
    while int(dut.cs_n.value) == 0:
        await RisingEdge(dut.PCLK)

@cocotb.test()
async def test_spi_rx(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.miso.value = 0

    dut.PRESETn.value = 0
    for _ in range(5):
        await RisingEdge(dut.PCLK)
    dut.PRESETn.value = 1
    for _ in range(3):
        await RisingEdge(dut.PCLK)

    rx_expect = 0xA5
    # TX dummy 0x00 while we inject RX
    miso_task = cocotb.start_soon(drive_miso_byte(dut, rx_expect))
    await apb_write(dut, 0x00)
    await miso_task

    # wait busy clear
    for _ in range(50):
        await RisingEdge(dut.PCLK)
        r = await apb_read(dut)
        busy = r & 1
        if busy == 0:
            rx = (r >> 8) & 0xFF
            cocotb.log.info(f"[SB] RX DATA=0x{rx:02x} expect=0x{rx_expect:02x}")
            assert rx == rx_expect, f"got 0x{rx:02x}"
            cocotb.log.info("*** MDV SPI RX PASS ***")
            return
    assert False, "SPI stayed busy"
