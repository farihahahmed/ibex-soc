import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_scan_smoke(dut):
    """Reset → outputs idle."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.scan_in.value = 0
    dut.scan_shift.value = 0
    dut.scan_load.value = 0
    dut.scan_i0o1.value = 0
    dut.mem_rdata.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    for _ in range(5):
        await RisingEdge(dut.clk)

    assert int(dut.mem_we.value) == 0
    assert int(dut.fsm_cfg_load.value) == 0
    assert int(dut.clk_cfg_load.value) == 0
    cocotb.log.info("*** SCAN smoke PASS ***")
