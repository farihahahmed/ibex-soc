"""UART depth tests -- the behaviors beyond a single happy-path byte.

Pins down, against the RTL as built (rtl/uart.sv):
  1. back-to-back TX frames via the busy handshake
  2. RX overrun: second byte overwrites, rx_valid stays set (KNOWN_GAPS: no
     overrun flag -- this test *documents* the actual behavior)
  3. false start: a glitch shorter than half a bit must not produce a byte
  4. bad stop bit: RTL has no framing check, byte is still accepted
     (documents the gap; if framing detection is ever added, update this test)
  5. mid-frame reset: reset during RX recovers cleanly, next frame OK

All register access goes through the RAL model (tb.reg_model.soc_regs).
DUT: apb_uart with CLK_FREQ=8, BAUD_RATE=1 -> BAUD_DIV=8 clocks per bit.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tb.reg_model.soc_regs import uart

BIT = 8  # BAUD_DIV at the block-test parameters


async def reset(dut, start_clock=True):
    # cocotb 2.0 kills spawned tasks between tests: every test must start its
    # own clock. start_clock=False for a second reset within the same test.
    if start_clock:
        cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.rx.value = 1
    await Timer(50, unit="ns")
    dut.PRESETn.value = 1
    for _ in range(5):
        await RisingEdge(dut.PCLK)


async def apb_write(dut, addr, data):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1; dut.PWRITE.value = 1
    dut.PADDR.value = addr; dut.PWDATA.value = data
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    while int(dut.PREADY.value) == 0:
        await RisingEdge(dut.PCLK)
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0; dut.PENABLE.value = 0; dut.PWRITE.value = 0


async def apb_read(dut, addr):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1; dut.PWRITE.value = 0
    dut.PADDR.value = addr; dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    while int(dut.PREADY.value) == 0:
        await RisingEdge(dut.PCLK)
    val = int(dut.PRDATA.value)
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0; dut.PENABLE.value = 0
    return val


async def wait_not_busy(dut, timeout=BIT * 20):
    for _ in range(timeout):
        st = await apb_read(dut, uart.status.offset)
        if uart.status.field("tx_busy", st) == 0:
            return
    raise AssertionError("tx_busy never cleared")


async def drive_rx_frame(dut, byte, stop_bit=1):
    """Drive one frame on the rx pin: start, 8 data LSB-first, stop."""
    dut.rx.value = 0
    for _ in range(BIT):
        await RisingEdge(dut.PCLK)
    for i in range(8):
        dut.rx.value = (byte >> i) & 1
        for _ in range(BIT):
            await RisingEdge(dut.PCLK)
    dut.rx.value = stop_bit
    for _ in range(BIT):
        await RisingEdge(dut.PCLK)
    dut.rx.value = 1
    for _ in range(4):
        await RisingEdge(dut.PCLK)


async def rx_byte_via_model(dut):
    st = await apb_read(dut, uart.status.offset)
    assert uart.status.field("rx_valid", st) == 1, \
        f"expected rx_valid; STATUS: {uart.status.decode(st)}"
    d = await apb_read(dut, uart.data.offset)
    return uart.data.field("rx", d)


@cocotb.test()
async def test_tx_back_to_back(dut):
    """Three frames driven straight off the busy handshake, no idle gap."""
    await reset(dut)
    for b in (0x55, 0xA3, 0x0F):
        await apb_write(dut, uart.data.offset, uart.data.encode(tx=b))
        st = await apb_read(dut, uart.status.offset)
        assert uart.status.field("tx_busy", st) == 1, "busy must assert per frame"
        await wait_not_busy(dut)
    cocotb.log.info("*** UART back-to-back TX PASS ***")


@cocotb.test()
async def test_rx_overrun_overwrites(dut):
    """Two frames, no read between: second byte wins, rx_valid still set.
    Documents the no-overrun-flag gap (KNOWN_GAPS.md)."""
    await reset(dut)
    await drive_rx_frame(dut, 0x11)
    await drive_rx_frame(dut, 0x22)
    got = await rx_byte_via_model(dut)
    assert got == 0x22, f"overrun should overwrite: got 0x{got:02x}, want 0x22"
    st = await apb_read(dut, uart.status.offset)
    assert uart.status.field("rx_valid", st) == 0, "read must consume the byte"
    cocotb.log.info("*** UART overrun-overwrite (documented) PASS ***")


@cocotb.test()
async def test_rx_false_start_glitch(dut):
    """A low glitch shorter than half a bit must be rejected at the mid-bit
    resample -- no byte, no rx_valid."""
    await reset(dut)
    dut.rx.value = 0
    for _ in range(2):                 # 2 clocks << BAUD_DIV/2 = 4
        await RisingEdge(dut.PCLK)
    dut.rx.value = 1
    for _ in range(BIT * 12):          # would-be frame duration
        await RisingEdge(dut.PCLK)
    st = await apb_read(dut, uart.status.offset)
    assert uart.status.field("rx_valid", st) == 0, \
        f"glitch produced a byte: {uart.status.decode(st)}"
    cocotb.log.info("*** UART false-start rejection PASS ***")


@cocotb.test()
async def test_rx_bad_stop_bit_accepted(dut):
    """RTL performs no stop-bit check: a frame with stop=0 is still accepted.
    This DOCUMENTS current behavior; flip the assertion if framing detection
    is ever added."""
    await reset(dut)
    await drive_rx_frame(dut, 0x5A, stop_bit=0)
    got = await rx_byte_via_model(dut)
    assert got == 0x5A, f"byte with bad stop: got 0x{got:02x}, want 0x5A"
    cocotb.log.info("*** UART bad-stop accepted (documented, no framing check) PASS ***")


@cocotb.test()
async def test_rx_midframe_reset_recovers(dut):
    """Reset in the middle of a frame: rx_valid must be clear afterwards and
    the next good frame must be received normally."""
    await reset(dut)
    # start a frame, reset halfway through the data bits
    dut.rx.value = 0
    for _ in range(BIT):
        await RisingEdge(dut.PCLK)
    dut.rx.value = 1                   # first data bit
    for _ in range(BIT * 2):
        await RisingEdge(dut.PCLK)
    await reset(dut, start_clock=False)  # yank reset mid-frame
    st = await apb_read(dut, uart.status.offset)
    assert uart.status.field("rx_valid", st) == 0, "rx_valid must clear on reset"
    await drive_rx_frame(dut, 0xC7)
    got = await rx_byte_via_model(dut)
    assert got == 0xC7, f"post-reset frame: got 0x{got:02x}, want 0xC7"
    cocotb.log.info("*** UART mid-frame reset recovery PASS ***")
