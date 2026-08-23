import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_fsm_run(dut):
    """cfg_load RUN → mode=1, scan_owns=0, cpu_clk tracks clk."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.cfg_load.value = 0
    dut.cfg_mode_in.value = 0
    dut.cfg_count_in.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)

    # Align to negedge so cfg_load is stable into next posedge
    await FallingEdge(dut.clk)
    dut.cfg_mode_in.value = 1  # RUN
    dut.cfg_count_in.value = 0
    dut.cfg_load.value = 1
    await RisingEdge(dut.clk)   # mode samples here
    dut.cfg_load.value = 0
    await FallingEdge(dut.clk)  # run_gate_q samples here
    await RisingEdge(dut.clk)   # first gated high cycle

    mode = int(dut.mode_o.value)
    owns = int(dut.scan_owns_mem.value)
    cocotb.log.info(f"after load: mode={mode} owns={owns}")
    assert mode == 1, f"mode={mode}"
    assert owns == 0, f"owns={owns}"

    highs = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")  # sample mid-high
        if int(dut.cpu_clk.value) == 1:
            highs += 1
    assert highs >= 5, f"cpu_clk not running (highs={highs})"
    cocotb.log.info(f"*** FSM RUN PASS (cpu_clk highs={highs}/10) ***")
