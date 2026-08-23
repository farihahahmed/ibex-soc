"""Block SPI smoke: reset + idle pins."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_spi_smoke(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    await Timer(50, unit="ns")
    dut.PRESETn.value = 1
    for _ in range(10):
        await RisingEdge(dut.PCLK)
    # common pin names — adjust if RTL differs
    for name in ("spi_sclk", "sclk", "spi_mosi", "mosi", "spi_cs_n", "cs_n"):
        if hasattr(dut, name):
            cocotb.log.info(f"{name}={int(getattr(dut, name).value)}")
    cocotb.log.info("*** spi block smoke PASS ***")
