"""PSEL=0 → nobody selected."""
import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_decoder_smoke(dut):
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0x00010000
    dut.PWDATA.value = 0
    dut.gpio_PRDATA.value = 0x11
    dut.gpio_PREADY.value = 1
    dut.uart_PRDATA.value = 0x22
    dut.uart_PREADY.value = 1
    dut.spi_PRDATA.value = 0x33
    dut.spi_PREADY.value = 1
    await Timer(1, unit="ns")
    assert int(dut.gpio_PSEL.value) == 0
    assert int(dut.uart_PSEL.value) == 0
    assert int(dut.spi_PSEL.value) == 0
    cocotb.log.info("*** decoder smoke PASS ***")
