"""Integration: scan frame tgt=1 RUN → test_fsm mode + cpu_clk live."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def shift_frame(dut, frame48):
    for i in range(48):
        dut.scan_in.value = (frame48 >> i) & 1
        dut.scan_shift.value = 1
        await RisingEdge(dut.clk)
    dut.scan_shift.value = 0
    dut.scan_in.value = 0
    await RisingEdge(dut.clk)
    dut.scan_load.value = 1
    await RisingEdge(dut.clk)
    dut.scan_load.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_scan_fsm_int(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.scan_in.value = 0
    dut.scan_shift.value = 0
    dut.scan_load.value = 0
    dut.scan_i0o1.value = 0
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    for _ in range(4):
        await RisingEdge(dut.clk)

    assert int(dut.mode_o.value) == 0
    assert int(dut.scan_owns_mem.value) == 1

    data = (1 << 16)  # mode=RUN
    frame = (1 << 46) | data
    await shift_frame(dut, frame)

    for _ in range(4):
        await RisingEdge(dut.clk)

    mode = int(dut.mode_o.value)
    owns = int(dut.scan_owns_mem.value)
    cocotb.log.info(f"after RUN: mode={mode} owns={owns}")
    assert mode == 1, f"mode={mode} expect RUN(1)"
    assert owns == 0

    # Sample on BOTH edges — cpu_clk = clk & gate, so it must fall with clk
    toggles = 0
    last = int(dut.cpu_clk.value)
    for _ in range(20):
        await RisingEdge(dut.clk)
        cur = int(dut.cpu_clk.value)
        if cur != last:
            toggles += 1
            last = cur
        await FallingEdge(dut.clk)
        cur = int(dut.cpu_clk.value)
        if cur != last:
            toggles += 1
            last = cur

    assert toggles >= 10, f"cpu_clk toggles={toggles}"
    cocotb.log.info(f"*** SCAN+FSM INT PASS: mode=RUN cpu_clk toggles={toggles} ***")
