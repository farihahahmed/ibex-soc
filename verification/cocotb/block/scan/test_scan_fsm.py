import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def shift_frame(dut, frame48):
    for i in range(48):
        dut.scan_in.value = (frame48 >> i) & 1
        dut.scan_shift.value = 1
        await RisingEdge(dut.clk)
    dut.scan_shift.value = 0
    dut.scan_in.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_scan_fsm(dut):
    """tgt=1 FSM cfg: fsm_cfg_load, mode=RUN(1), count=0."""
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

    # data field: {14'h0, mode[1:0]=1, count[15:0]=0} → bits [17:16]=1, [15:0]=0
    # Matches chip TB: scan_frame(2'd1, 14'h0, {14'h0, 2'd1, 16'd0})
    tgt, addr, data = 1, 0, (1 << 16)  # mode=1 in data[17:16]
    frame = (tgt << 46) | (addr << 32) | data
    await shift_frame(dut, frame)

    assert int(dut.fsm_mode.value) == 1
    assert int(dut.fsm_count.value) == 0

    dut.scan_load.value = 1
    await RisingEdge(dut.clk)
    assert int(dut.fsm_cfg_load.value) == 1
    assert int(dut.mem_we.value) == 0
    dut.scan_load.value = 0
    await RisingEdge(dut.clk)
    assert int(dut.fsm_cfg_load.value) == 0
    cocotb.log.info("*** SCAN FSM PASS mode=RUN ***")
