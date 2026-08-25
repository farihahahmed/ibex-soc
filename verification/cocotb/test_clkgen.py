"""Clock generator: divider ratio and internal/external source switching.

Otherwise unexercised - every other test sends tgt=2 with data=0, leaving
clk_div=0 and clk_int=0 (external passthrough). Covers:
  1. external passthrough  - sys_clk follows clk 1:1
  2. non-zero divider      - period = 2*(div+1) * clk period
  3. source switch         - handover completes and the clock keeps running

use_internal = clkgen_int & clk_int, so the scan bit AND the pin must be high.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer, First
from cocotb.utils import get_sim_time

FRAME_BITS = 48


async def shift_frame(dut, tgt, addr, data):
    frame = ((tgt & 0x3) << 46) | ((addr & 0x3FFF) << 32) | (data & 0xFFFFFFFF)
    for i in range(FRAME_BITS):
        await FallingEdge(dut.clk)
        dut.scan_in.value    = (frame >> i) & 1
        dut.scan_shift.value = 1
    await FallingEdge(dut.clk)
    dut.scan_shift.value = 0
    dut.scan_in.value    = 0
    await FallingEdge(dut.clk)
    dut.scan_load.value = 1
    await FallingEdge(dut.clk)
    dut.scan_load.value = 0
    await RisingEdge(dut.clk)


async def measure(dut, timeout_ns=20000):
    sig = dut.u_clkgen.clk_out
    t = Timer(timeout_ns, unit="ns")
    if (await First(RisingEdge(sig), t)) is t:
        return None
    t0 = get_sim_time(unit="ns")
    t2 = Timer(timeout_ns, unit="ns")
    if (await First(RisingEdge(sig), t2)) is t2:
        return None
    return get_sim_time(unit="ns") - t0


@cocotb.test()
async def test_clkgen_divider_and_source(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.clk_int.value = 0
    dut.scan_in.value = 0
    dut.scan_shift.value = 0
    dut.scan_load.value = 0
    dut.scan_i0o1.value = 0
    dut.gpio_in.value = 0
    dut.uart_rx.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    p = await measure(dut)
    dut._log.info(f"external: period={p} ns (expect 10)")
    assert p is not None, "sys_clk never toggled on external source"
    assert abs(p - 10) < 1, f"external passthrough wrong: {p}"

    DIV = 3
    await shift_frame(dut, tgt=2, addr=0, data=(1 << 8) | DIV)
    dut.clk_int.value = 1
    await ClockCycles(dut.clk, 40)
    p = await measure(dut)
    exp = 2 * (DIV + 1) * 10
    dut._log.info(f"internal div={DIV}: period={p} ns (expect {exp})")
    assert p is not None, "sys_clk STOPPED after switching to internal source"
    assert abs(p - exp) < 5, f"divider wrong: {p}, expected {exp}"

    dut.clk_int.value = 0
    await ClockCycles(dut.clk, 40)
    p = await measure(dut)
    dut._log.info(f"back to external: period={p} ns (expect 10)")
    assert p is not None, "sys_clk STOPPED switching back to external"
    assert abs(p - 10) < 1, f"switch back wrong: {p}"

    dut._log.info("*** clk_gen divider + source switching PASS ***")
