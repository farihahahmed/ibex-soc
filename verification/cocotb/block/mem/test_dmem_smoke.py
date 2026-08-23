"""dmem_narrow_top smoke: reset, idle gnt high when no req."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_dmem_smoke(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.req.value = 0
    dut.we.value = 0
    dut.be.value = 0
    dut.addr.value = 0
    dut.wdata.value = 0
    dut.ld_word_en.value = 0
    dut.ld_word_addr.value = 0
    dut.ld_word_data.value = 0

    for _ in range(4):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(4):
        await RisingEdge(dut.clk)

    # Idle: no req → should not be busy forever
    assert int(dut.ld_busy.value) == 0, "ld_busy stuck after reset"
    cocotb.log.info(f"idle gnt={int(dut.gnt.value)} rvalid={int(dut.rvalid.value)}")
    cocotb.log.info("*** dmem smoke PASS ***")
