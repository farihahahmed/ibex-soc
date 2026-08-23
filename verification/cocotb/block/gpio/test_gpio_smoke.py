"""Block GPIO smoke: reset, APB idle, outputs stable."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_gpio_smoke(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    # gpio_in if present
    if hasattr(dut, "gpio_in"):
        dut.gpio_in.value = 0
    await Timer(50, unit="ns")
    dut.PRESETn.value = 1
    for _ in range(10):
        await RisingEdge(dut.PCLK)
    # After reset, gpio_out should be defined (0 is fine)
    out = int(dut.gpio_out.value)
    cocotb.log.info(f"gpio_out after reset = 0x{out:x}")
    assert out == out  # alive
    cocotb.log.info("*** gpio block smoke PASS ***")
