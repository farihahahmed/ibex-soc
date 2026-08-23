import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def shift_frame(dut, frame48):
    """LSB-first: bit0 goes in first (matches RTL {scan_in, shift_reg[47:1]})."""
    for i in range(48):
        dut.scan_in.value = (frame48 >> i) & 1
        dut.scan_shift.value = 1
        await RisingEdge(dut.clk)
    dut.scan_shift.value = 0
    dut.scan_in.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_scan_mem(dut):
    """tgt=0 MEMORY write: mem_we pulse, addr+data correct."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.scan_in.value = 0
    dut.scan_shift.value = 0
    dut.scan_load.value = 0
    dut.scan_i0o1.value = 0
    dut.mem_rdata.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)

    tgt, addr, data = 0, 0x0005, 0xDEADBEEF
    frame = (tgt << 46) | (addr << 32) | data
    await shift_frame(dut, frame)

    # Check decoded before load
    assert int(dut.mem_addr.value) == addr
    assert int(dut.mem_wdata.value) == data
    assert int(dut.mem_we.value) == 0

    # Pulse load
    dut.scan_load.value = 1
    await RisingEdge(dut.clk)
    assert int(dut.mem_we.value) == 1
    assert int(dut.fsm_cfg_load.value) == 0
    dut.scan_load.value = 0
    await RisingEdge(dut.clk)
    assert int(dut.mem_we.value) == 0
    cocotb.log.info(f"*** SCAN MEM PASS addr=0x{addr:x} data=0x{data:08x} ***")
