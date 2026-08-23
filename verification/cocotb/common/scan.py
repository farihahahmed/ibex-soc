"""Reusable scan-chain helpers for ibex-soc"""

from cocotb.triggers import FallingEdge, RisingEdge

async def scan_frame(dut, tgt, addr, data):
    """
    Send one 48-bit scan frame.
    Format: {tgt[1:0], addr[13:0], data[31:0]}
    Bit order: LSB first (required by this design)
    """
    frame = (tgt << 46) | ((addr & 0x3FFF) << 32) | (data & 0xFFFFFFFF)

    for i in range(48):
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


async def load_program(dut, words):
    """Load a list of 32-bit words into instruction memory via scan"""
    for i, word in enumerate(words):
        await scan_frame(dut, tgt=0, addr=i, data=word)


async def start_cpu(dut):
    """Put the test FSM into RUN mode"""
    await scan_frame(dut, tgt=2, addr=0, data=0x00000000)  # clkgen cfg
    await scan_frame(dut, tgt=1, addr=0, data=0x00010000)  # mode = RUN
