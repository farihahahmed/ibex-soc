"""Status readback over scan (tgt=3, addr[13]=1).

Status word:
  [0]    CPU trap (sticky since reset)
  [2:1]  FSM mode (0=IDLE, 1=RUN, 2=COUNTDOWN)
  [3]    scan owns memory
This is the only way to observe a CPU trap: a trapped CPU cannot report it in
software, and there is no spare pin.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles

FRAME_BITS = 48
STATUS_ADDR = 1 << 13          # addr[13]=1 selects status, not memory


async def shift_frame(dut, tgt, addr, data):
    frame = ((tgt & 0x3) << 46) | ((addr & 0x3FFF) << 32) | (data & 0xFFFFFFFF)
    for i in range(FRAME_BITS):
        await FallingEdge(dut.clk)
        dut.scan_in.value = (frame >> i) & 1
        dut.scan_shift.value = 1
    await FallingEdge(dut.clk)
    dut.scan_shift.value = 0
    dut.scan_in.value = 0
    await FallingEdge(dut.clk)
    dut.scan_load.value = 1
    await FallingEdge(dut.clk)
    dut.scan_load.value = 0
    await RisingEdge(dut.clk)


async def capture_out(dut):
    await FallingEdge(dut.clk)
    dut.scan_i0o1.value = 1
    await FallingEdge(dut.clk)
    dut.scan_i0o1.value = 0
    await RisingEdge(dut.clk)
    val = 0
    for i in range(FRAME_BITS):
        await FallingEdge(dut.clk)
        val |= (int(dut.scan_out.value) & 1) << i
        dut.scan_shift.value = 1
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.scan_shift.value = 0
    return val & 0xFFFFFFFF


@cocotb.test()
async def test_scan_status(dut):
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

    # after reset: IDLE (mode 0), scan owns memory (bit 3), no trap
    await shift_frame(dut, tgt=3, addr=STATUS_ADDR, data=0)
    st = await capture_out(dut)
    dut._log.info(f"status after reset = 0x{st:08x}")
    assert (st & 1) == 0, "trap should be clear after reset"
    assert ((st >> 1) & 3) == 0, f"expected mode IDLE, got {(st >> 1) & 3}"
    assert (st >> 3) & 1 == 1, "scan should own memory in IDLE"

    # put the FSM in RUN, status must follow
    await shift_frame(dut, tgt=1, addr=0, data=0x00010000)
    await ClockCycles(dut.clk, 5)
    await shift_frame(dut, tgt=3, addr=STATUS_ADDR, data=0)
    st = await capture_out(dut)
    dut._log.info(f"status in RUN     = 0x{st:08x}")
    assert ((st >> 1) & 3) == 1, f"expected mode RUN, got {(st >> 1) & 3}"
    assert (st >> 3) & 1 == 0, "scan must not own memory in RUN"

    dut._log.info("*** scan status readback PASS ***")
