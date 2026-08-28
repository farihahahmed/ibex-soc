"""R-BOOT-09: force a real CPU trap and observe it via the status word.

picorv32 is built with CATCH_ILLINSN=1, so an illegal instruction raises `trap`.
chip_top_full synchronises that into sys_clk and latches it into a sticky bit,
readable as status_word[0] over the scan chain (tgt=3, addr[13]=1). A trapped
CPU cannot report in software and there is no spare pin, so this is the only
observation path.

This test loads a program whose first fetched instruction is illegal, runs the
CPU, and asserts the trap bit sets and stays set (sticky). It closes R-BOOT-09
from Partial (path verified) to a forced-and-observed trap.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles

FRAME_BITS = 48
STATUS_ADDR = 1 << 13

# 0x00000000 is not a legal RV32 opcode (not lui/auipc/jal/jalr/branch/load/
# store/op-imm/op/system), so picorv32 with CATCH_ILLINSN raises trap on it.
ILLEGAL_INSN = 0x00000000


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
async def test_scan_trap(dut):
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

    # trap must be clear coming out of reset
    await shift_frame(dut, tgt=3, addr=STATUS_ADDR, data=0)
    st = await capture_out(dut)
    dut._log.info(f"status after reset = 0x{st:08x}")
    assert (st & 1) == 0, f"trap should be clear after reset, status=0x{st:08x}"

    # load an illegal instruction at word 0 (tgt=0 = memory write)
    await shift_frame(dut, tgt=0, addr=0, data=ILLEGAL_INSN)

    # run the CPU (tgt=1); it fetches word 0, decodes illegal, and traps
    await shift_frame(dut, tgt=1, addr=0, data=0x00010000)

    # allow fetch -> decode -> trap -> 2-flop sys_clk sync -> sticky latch.
    # sys_clk = clk/2, so give generous headroom.
    await ClockCycles(dut.clk, 200)

    # trap bit must now be set
    await shift_frame(dut, tgt=3, addr=STATUS_ADDR, data=0)
    st = await capture_out(dut)
    dut._log.info(f"status after illegal insn = 0x{st:08x}")
    assert (st & 1) == 1, (
        f"trap bit should be SET after executing an illegal instruction, "
        f"status=0x{st:08x}"
    )

    # trap is sticky: a second read must still show it set
    await ClockCycles(dut.clk, 20)
    await shift_frame(dut, tgt=3, addr=STATUS_ADDR, data=0)
    st2 = await capture_out(dut)
    assert (st2 & 1) == 1, f"trap bit must be sticky, second read=0x{st2:08x}"

    dut._log.info("*** R-BOOT-09 PASS: illegal instruction forced a trap, "
                  "observed sticky via status word ***")
