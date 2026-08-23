import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_fsm_countdown(dut):
    """COUNTDOWN count=4 → clk runs briefly then gates."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.cfg_load.value = 0
    dut.cfg_mode_in.value = 0
    dut.cfg_count_in.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.cfg_mode_in.value = 2
    dut.cfg_count_in.value = 4
    dut.cfg_load.value = 1
    await RisingEdge(dut.clk)
    dut.cfg_load.value = 0
    await FallingEdge(dut.clk)

    highs = 0
    for _ in range(20):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        if int(dut.cpu_clk.value) == 1:
            highs += 1

    assert highs >= 2, f"expected some cpu_clk activity, got {highs}"
    assert highs < 18, f"clk should gate after countdown, highs={highs}"
    assert int(dut.mode_o.value) == 2
    cocotb.log.info(f"*** FSM COUNTDOWN PASS (highs={highs}/20) ***")
