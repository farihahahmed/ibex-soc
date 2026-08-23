import cocotb
from cocotb.triggers import Timer
from common import init_dut, load_program, start_cpu
from vip import GpioMonitor, UartMonitor, SpiMonitor
from coverage import cov

@cocotb.test()
async def test_chip_v2_port(dut):
    """Full functional check + coverage"""

    await init_dut(dut)
    cocotb.log.info("Reset released")
    cov.hit("reset_released")

    gpio_mon = GpioMonitor(dut)
    uart_mon = UartMonitor(dut, bit_cycles=8)
    spi_mon  = SpiMonitor(dut)

    cocotb.start_soon(gpio_mon.run())
    cocotb.start_soon(uart_mon.run())
    cocotb.start_soon(spi_mon.run())

    prog = [
        0x00010537, 0x000205B7, 0x00030637,
        0x0A500293, 0x04100313, 0x0B700393,
        0x00552023, 0x0065A023, 0x00762023,
        0x00000013, 0xFFDFF06F,
        0x00000013, 0x00000013, 0x00000013, 0x00000013, 0x00000013,
    ]

    cocotb.log.info("Loading program...")
    await load_program(dut, prog)
    cov.hit("program_loaded", len(prog))

    await start_cpu(dut)
    cov.hit("fsm_run")
    cocotb.log.info("CPU running...")

    await Timer(20000, unit="ns")

    gpio_val = gpio_mon.get_final()
    uart_byte = uart_mon.bytes[0] if uart_mon.bytes else 0
    spi_byte  = spi_mon.bytes[0]  if spi_mon.bytes  else 0

    # Coverage points
    cov.hit("gpio_value", gpio_val)
    cov.hit("uart_byte", uart_byte)
    cov.hit("spi_byte", spi_byte)

    if gpio_val == 0x05:
        cov.hit("gpio_expected")
    if uart_byte == 0x41:
        cov.hit("uart_expected")
    if spi_byte == 0xB7:
        cov.hit("spi_expected")

    cocotb.log.info("--------------------------------------------------")
    cocotb.log.info(f"  GPIO out : 0x{gpio_val:02x} (expect 0x05)")
    cocotb.log.info(f"  UART sent: 0x{uart_byte:02x} (expect 0x41)")
    cocotb.log.info(f"  SPI MOSI : 0x{spi_byte:02x} (expect 0xB7)")
    cocotb.log.info("--------------------------------------------------")

    assert gpio_val == 0x05
    assert uart_byte == 0x41
    assert spi_byte  == 0xB7

    cov.hit("test_passed")
    cov.report()
    cocotb.log.info("*** PASS ***")
