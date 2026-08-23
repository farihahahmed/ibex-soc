"""PADDR[17:16] selects GPIO/UART/SPI and muxes PRDATA."""
import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_decoder_regions(dut):
    dut.PENABLE.value = 1
    dut.PWRITE.value = 0
    dut.PWDATA.value = 0
    dut.gpio_PRDATA.value = 0x11111111
    dut.gpio_PREADY.value = 1
    dut.uart_PRDATA.value = 0x22222222
    dut.uart_PREADY.value = 1
    dut.spi_PRDATA.value = 0x33333333
    dut.spi_PREADY.value = 1

    # GPIO 0x0001_xxxx
    dut.PSEL.value = 1
    dut.PADDR.value = 0x00010000
    await Timer(1, unit="ns")
    assert int(dut.gpio_PSEL.value) == 1
    assert int(dut.uart_PSEL.value) == 0
    assert int(dut.spi_PSEL.value) == 0
    assert int(dut.PRDATA.value) == 0x11111111

    # UART 0x0002_xxxx
    dut.PADDR.value = 0x00020004
    await Timer(1, unit="ns")
    assert int(dut.uart_PSEL.value) == 1
    assert int(dut.gpio_PSEL.value) == 0
    assert int(dut.PRDATA.value) == 0x22222222

    # SPI 0x0003_xxxx
    dut.PADDR.value = 0x00030000
    await Timer(1, unit="ns")
    assert int(dut.spi_PSEL.value) == 1
    assert int(dut.PRDATA.value) == 0x33333333

    # unmapped 0x0000_xxxx → nobody
    dut.PADDR.value = 0x00000000
    await Timer(1, unit="ns")
    assert int(dut.gpio_PSEL.value) == 0
    assert int(dut.uart_PSEL.value) == 0
    assert int(dut.spi_PSEL.value) == 0

    cocotb.log.info("*** decoder regions PASS ***")
