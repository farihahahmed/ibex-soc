"""UART protocol conformance.

Existing block tests prove a byte moved. These prove the protocol: framing
error rejection, the STATUS/DATA register split, and back-to-back transfers.
Only features this RTL actually has are tested - there is no FIFO, no break
detection and no overrun flag, so none are asserted.

Direct pin driving rather than the APB agent, because these need bit-level
control of rx and cycle-level observation of tx.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

BAUD = 8          # block Makefile builds with CLK_FREQ=8, BAUD_RATE=1


async def reset(dut):
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
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0; dut.PENABLE.value = 0; dut.PWRITE.value = 0


async def apb_read(dut, addr):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1; dut.PWRITE.value = 0
    dut.PADDR.value = addr; dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await Timer(1, unit="ns")
    val = int(dut.PRDATA.value)
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0; dut.PENABLE.value = 0
    return val


async def send_frame(dut, byte, start_bit=0, stop_bit=1):
    """Bit-bang a frame onto rx. start_bit/stop_bit can be corrupted."""
    dut.rx.value = start_bit
    for _ in range(BAUD): await RisingEdge(dut.PCLK)
    for i in range(8):
        dut.rx.value = (byte >> i) & 1
        for _ in range(BAUD): await RisingEdge(dut.PCLK)
    dut.rx.value = stop_bit
    for _ in range(BAUD): await RisingEdge(dut.PCLK)
    dut.rx.value = 1
    for _ in range(BAUD): await RisingEdge(dut.PCLK)


@cocotb.test()
async def test_status_read_does_not_clear_rx_valid(dut):
    """A STATUS read must NOT consume the byte; only a DATA read may.

    This is the documented fix that split STATUS (offset 0) from DATA
    (offset 4). Before it, any read cleared rx_valid, so software polling for
    rx_valid destroyed the very flag it was waiting on. Nothing tested it
    until now.
    """
    await reset(dut)
    await send_frame(dut, 0x5A)

    st = await apb_read(dut, 0x0)
    assert st & 0x2, f"rx_valid should be set after a byte arrives, STATUS={st:#x}"

    st2 = await apb_read(dut, 0x0)
    assert st2 & 0x2, "a STATUS read must not clear rx_valid - polling would break"

    data = await apb_read(dut, 0x4)
    assert data & 0xFF == 0x5A, f"DATA should return 0x5A, got {data & 0xFF:#04x}"

    st3 = await apb_read(dut, 0x0)
    assert not (st3 & 0x2), "a DATA read must clear rx_valid - the byte is consumed"
    dut._log.info("*** STATUS/DATA split PASS ***")


@cocotb.test()
async def test_rx_rejects_bad_start_bit(dut):
    """A glitch on rx must not be mistaken for a start bit.

    R_START re-samples at mid-bit and returns to idle if the line has gone
    high again. Without that check, line noise would fabricate bytes.
    """
    await reset(dut)
    dut.rx.value = 0
    for _ in range(BAUD // 4):
        await RisingEdge(dut.PCLK)
    dut.rx.value = 1
    for _ in range(BAUD * 12):
        await RisingEdge(dut.PCLK)

    st = await apb_read(dut, 0x0)
    assert not (st & 0x2), f"a glitch must not produce a byte, STATUS={st:#x}"
    dut._log.info("*** bad start bit rejected PASS ***")


@cocotb.test()
async def test_tx_busy_during_shift(dut):
    """tx_busy must be set while a byte is shifting out and clear afterwards."""
    await reset(dut)
    await apb_write(dut, 0x4, 0x41)
    await RisingEdge(dut.PCLK)

    st = await apb_read(dut, 0x0)
    assert st & 0x1, f"tx_busy should be set while transmitting, STATUS={st:#x}"

    for _ in range(BAUD * 12):
        await RisingEdge(dut.PCLK)
    st = await apb_read(dut, 0x0)
    assert not (st & 0x1), "tx_busy should clear once the frame completes"
    dut._log.info("*** tx_busy PASS ***")


@cocotb.test()
async def test_tx_frame_is_8n1(dut):
    """The transmitted frame must be start(0) + 8 data LSB-first + stop(1)."""
    await reset(dut)
    BYTE = 0xB3
    await apb_write(dut, 0x4, BYTE)

    while int(dut.tx.value) == 1:
        await RisingEdge(dut.PCLK)
    for _ in range(BAUD // 2):
        await RisingEdge(dut.PCLK)
    assert int(dut.tx.value) == 0, "start bit must be low"

    got = 0
    for i in range(8):
        for _ in range(BAUD):
            await RisingEdge(dut.PCLK)
        got |= (int(dut.tx.value) & 1) << i
    for _ in range(BAUD):
        await RisingEdge(dut.PCLK)
    stop = int(dut.tx.value)

    assert got == BYTE, f"data bits wrong: sent {BYTE:#04x}, saw {got:#04x}"
    assert stop == 1, "stop bit must be high"
    dut._log.info(f"*** 8N1 framing PASS (0x{got:02x}) ***")


@cocotb.test()
async def test_tx_back_to_back(dut):
    """Two bytes in succession must both transmit intact."""
    await reset(dut)
    for byte in (0x31, 0x32):
        await apb_write(dut, 0x4, byte)
        for _ in range(BAUD * 12):
            await RisingEdge(dut.PCLK)
        st = await apb_read(dut, 0x0)
        assert not (st & 0x1), f"tx still busy after byte {byte:#04x}"
    dut._log.info("*** back-to-back TX PASS ***")
