"""clk_gen: clk_int=0 → clk_out == clk_ext continuously."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_clkgen_smoke(dut):
    cocotb.start_soon(Clock(dut.ref_clk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.clk_ext, 20, unit="ns").start())

    dut.rst_n.value = 0
    dut.clk_int.value = 0
    dut.cfg_load.value = 0
    dut.cfg_div_in.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    await Timer(20, unit="ns")

    for _ in range(6):
        await RisingEdge(dut.clk_ext)
        await Timer(1, unit="ns")
        assert int(dut.clk_out.value) == 1, "clk_out high after clk_ext rise"
        await FallingEdge(dut.clk_ext)
        await Timer(1, unit="ns")
        assert int(dut.clk_out.value) == 0, "clk_out low after clk_ext fall"

    cocotb.log.info("*** clkgen smoke PASS ***")
