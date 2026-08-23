"""Block SPI directed: write 0xA5, expect CS low + SCLK edges."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def apb_write(dut, data):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1
    dut.PENABLE.value = 0
    dut.PWRITE.value = 1
    dut.PADDR.value = 0
    dut.PWDATA.value = data
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0
    dut.PENABLE.value = 0

@cocotb.test()
async def test_spi_tx(dut):
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

    assert int(dut.cs_n.value) == 1, "CS should be idle high"
    await apb_write(dut, 0xA5)

    saw_cs_low = False
    sclk_edges = 0
    last_sclk = int(dut.sclk.value)
    for _ in range(200):
        await RisingEdge(dut.PCLK)
        if int(dut.cs_n.value) == 0:
            saw_cs_low = True
        s = int(dut.sclk.value)
        if s != last_sclk:
            sclk_edges += 1
            last_sclk = s

    cocotb.log.info(f"cs_low={saw_cs_low} sclk_edges={sclk_edges}")
    assert saw_cs_low, "CS never went low"
    assert sclk_edges >= 2, f"too few SCLK edges: {sclk_edges}"
    cocotb.log.info("*** spi directed TX PASS ***")
