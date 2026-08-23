"""Reset and clock helpers"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

async def init_dut(dut, clk_period_ns=10):
    """Start clock and apply reset sequence (matches original TB)"""
    clock = Clock(dut.clk, clk_period_ns, unit="ns")
    cocotb.start_soon(clock.start())

    # Default inputs
    dut.rst_n.value = 0
    dut.scan_in.value = 0
    dut.scan_shift.value = 0
    dut.scan_load.value = 0
    dut.scan_i0o1.value = 0
    dut.gpio_in.value = 0
    dut.uart_rx.value = 1
    try:
        dut.clk_int.value = 0
    except AttributeError:
        pass

    # Reset sequence (same as original)
    await Timer(60, unit="ns")
    dut.rst_n.value = 1
    await Timer(40, unit="ns")
