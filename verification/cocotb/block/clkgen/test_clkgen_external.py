"""clk_int=0: clk_out is a pure mux of clk_ext (ignore divider)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_clkgen_external(dut):
    cocotb.start_soon(Clock(dut.ref_clk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.clk_ext, 14, unit="ns").start())

    dut.rst_n.value = 0
    dut.clk_int.value = 0
    dut.cfg_load.value = 0
    dut.cfg_div_in.value = 3  # should be ignored
    await Timer(40, unit="ns")
    dut.rst_n.value = 1
    await Timer(20, unit="ns")

    for _ in range(8):
        await RisingEdge(dut.clk_ext)
        await Timer(1, unit="ns")
        assert int(dut.clk_out.value) == 1
        await FallingEdge(dut.clk_ext)
        await Timer(1, unit="ns")
        assert int(dut.clk_out.value) == 0

    cocotb.log.info("*** clkgen external PASS ***")
