import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_fsm_smoke(dut):
    """Reset → IDLE, cpu_clk gated, scan_owns_mem=1."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.cfg_load.value = 0
    dut.cfg_mode_in.value = 0
    dut.cfg_count_in.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    for _ in range(5):
        await RisingEdge(dut.clk)

    assert int(dut.mode_o.value) == 0
    assert int(dut.scan_owns_mem.value) == 1
    assert int(dut.cpu_clk.value) == 0
    cocotb.log.info("*** FSM smoke PASS (IDLE, clk gated) ***")
