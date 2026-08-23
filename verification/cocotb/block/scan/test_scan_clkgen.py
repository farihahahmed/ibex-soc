"""Scan frame tgt=2 (CLKGEN): clk_int + clk_div fields on load."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

async def shift_only(dut, frame48):
    for i in range(48):
        await FallingEdge(dut.clk)
        dut.scan_in.value = (frame48 >> i) & 1
        dut.scan_shift.value = 1
    await FallingEdge(dut.clk)
    dut.scan_shift.value = 0
    dut.scan_in.value = 0

@cocotb.test()
async def test_scan_clkgen(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.scan_in.value = 0
    dut.scan_shift.value = 0
    dut.scan_load.value = 0
    dut.scan_i0o1.value = 0
    dut.mem_rdata.value = 0
    for _ in range(4):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)

    # RTL: clk_int = shift_reg[8], clk_div = shift_reg[7:0]
    clk_int, clk_div = 1, 0x2A
    data = (clk_int << 8) | clk_div
    frame = (2 << 46) | (0 << 32) | data  # tgt=2
    await shift_only(dut, frame)

    await FallingEdge(dut.clk)
    dut.scan_load.value = 1
    await RisingEdge(dut.clk)
    load = int(dut.clk_cfg_load.value)
    ci = int(dut.clk_int.value)
    cd = int(dut.clk_div.value)
    await FallingEdge(dut.clk)
    dut.scan_load.value = 0

    cocotb.log.info(f"clk_cfg_load={load} clk_int={ci} clk_div=0x{cd:02x}")
    assert load == 1
    assert ci == 1
    assert cd == 0x2A
    cocotb.log.info("*** scan clkgen PASS ***")
