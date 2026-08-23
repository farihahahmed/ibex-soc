"""Integration: scan COUNTDOWN → cpu_clk for N cycles, then gated."""
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

async def count_cpu_edges(dut, n_sys_cycles):
    toggles = 0
    last = int(dut.cpu_clk.value)
    for _ in range(n_sys_cycles):
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
    return toggles

@cocotb.test()
async def test_scan_fsm_countdown(dut):
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

    N = 8  # countdown cycles
    # data: mode[17:16]=2 (COUNTDOWN), count[15:0]=N
    data = (2 << 16) | N
    frame = (1 << 46) | data  # tgt=1 FSM
    await shift_frame(dut, frame)

    for _ in range(3):
        await RisingEdge(dut.clk)

    assert int(dut.mode_o.value) == 2, f"mode={int(dut.mode_o.value)}"
    live = await count_cpu_edges(dut, N + 2)
    assert live >= N, f"during countdown toggles={live}"

    # After count expires, cpu_clk should stay low
    for _ in range(6):
        await RisingEdge(dut.clk)
    dead = await count_cpu_edges(dut, 20)
    assert dead == 0, f"after expire still toggling={dead}"
    cocotb.log.info(f"*** COUNTDOWN PASS: live={live} then gated dead={dead} ***")
