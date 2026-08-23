"""clk_int=1: internal div_clk. period of clk_out = 2*(div+1) * ref_period."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_clkgen_div(dut):
    # ref 10 ns period
    cocotb.start_soon(Clock(dut.ref_clk, 10, unit="ns").start())
    dut.clk_ext.value = 0

    dut.rst_n.value = 0
    dut.clk_int.value = 1
    dut.cfg_load.value = 0
    dut.cfg_div_in.value = 1  # toggle every (1+1)=2 ref cycles → half-period 20ns → period 40ns
    await Timer(40, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.ref_clk)

    # load divider
    dut.cfg_load.value = 1
    await RisingEdge(dut.ref_clk)
    dut.cfg_load.value = 0

    # collect two rising edges of clk_out and measure
    await RisingEdge(dut.clk_out)
    t0 = cocotb.utils.get_sim_time(unit="ns")
    await RisingEdge(dut.clk_out)
    t1 = cocotb.utils.get_sim_time(unit="ns")
    period = t1 - t0

    # expected: 2*(div+1)*10 = 40 ns
    assert 35 <= period <= 45, f"period={period} ns expected ~40"
    cocotb.log.info(f"*** clkgen div PASS period={period} ns ***")
