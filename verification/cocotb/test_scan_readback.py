"""Scan-chain memory readback (tgt=3).

Proves the readback path added to imem_narrow_top actually returns memory
contents, rather than the zeros the top level used to tie off.

Protocol under test (see rtl/scan_chain.sv):
  1. shift in a frame  {tgt[1:0], addr[13:0], data[31:0]}, LSB first
  2. pulse scan_load
       tgt=0 -> write   data to word addr
       tgt=3 -> read    word addr into the holding register
  3. for a read, wait for the byte-gather to assemble the word
  4. pulse scan_i0o1 -> shift_reg[31:0] <= mem_rdata
  5. shift the frame out on scan_out (LSB first) and mask to 32 bits

Readback is only serviced while the FSM is IDLE (scan owns the memory), which
is the state after reset, so this test never starts the CPU.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles

FRAME_BITS = 48


async def reset(dut):
    dut.clk_int.value    = 0      # external clock source
    dut.scan_in.value    = 0
    dut.scan_shift.value = 0
    dut.scan_load.value  = 0
    dut.scan_i0o1.value  = 0
    dut.gpio_in.value    = 0
    dut.uart_rx.value    = 1
    dut.rst_n.value      = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    # the glitch-free clock mux needs a couple of edges before sys_clk runs
    await ClockCycles(dut.clk, 10)


async def shift_frame(dut, tgt, addr, data):
    """Shift a 48-bit frame in (LSB first) and pulse scan_load."""
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


async def capture_and_shift_out(dut):
    """Pulse scan_i0o1 to capture mem_rdata, then shift the frame out."""
    await FallingEdge(dut.clk)
    dut.scan_i0o1.value = 1
    await FallingEdge(dut.clk)
    dut.scan_i0o1.value = 0          # must be low: it has priority over shift
    await RisingEdge(dut.clk)

    val = 0
    for i in range(FRAME_BITS):
        # sample mid-cycle, where scan_out is stable, THEN request the shift
        await FallingEdge(dut.clk)
        val |= (int(dut.scan_out.value) & 1) << i
        dut.scan_shift.value = 1
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.scan_shift.value = 0
    return val & 0xFFFFFFFF          # only [31:0] is loaded by scan_i0o1


@cocotb.test()
async def test_scan_readback(dut):
    """Write known words over scan, read them back, compare."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    patterns = {
        0x00: 0xDEADBEEF,
        0x01: 0x12345678,
        0x05: 0xA5A5A5A5,
        0x7F: 0xCAFEF00D,     # last word of the 512 B imem
    }

    for addr, word in patterns.items():
        await shift_frame(dut, tgt=0, addr=addr, data=word)
        await ClockCycles(dut.clk, 12)          # let the 4-byte load finish
    dut._log.info(f"wrote {len(patterns)} words over scan")

    for addr, expected in patterns.items():
        await shift_frame(dut, tgt=3, addr=addr, data=0)
        await ClockCycles(dut.clk, 24)          # byte-gather assembles the word
        got = await capture_and_shift_out(dut)
        dut._log.info(f"addr 0x{addr:02x}: expected 0x{expected:08x}, got 0x{got:08x}")
        assert got == expected, (
            f"scan readback mismatch at word addr 0x{addr:02x}: "
            f"expected 0x{expected:08x}, got 0x{got:08x}"
        )

    dut._log.info("*** scan readback PASS ***")
