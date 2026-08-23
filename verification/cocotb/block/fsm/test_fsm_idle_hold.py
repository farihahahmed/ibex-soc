"""Negative: stay in IDLE — cpu_clk must never rise."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_fsm_idle_hold(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.cfg_load.value = 0
    dut.cfg_mode_in.value = 0
    dut.cfg_count_in.value = 0
    for _ in range(4):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    highs = 0
    for _ in range(40):
        await RisingEdge(dut.clk)
        await Timer(2, unit="ns")
        if int(dut.cpu_clk.value) == 1:
            highs += 1

    assert int(dut.mode_o.value) == 0
    assert int(dut.scan_owns_mem.value) == 1
    assert highs == 0, f"cpu_clk leaked high {highs} times in IDLE"
    cocotb.log.info("*** fsm IDLE hold (negative) PASS ***")
