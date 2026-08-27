"""SPI protocol conformance - Mode 0.

Existing tests count SCLK edges. These prove the mode: clock polarity, MOSI
bit order, CS framing, and that a transfer completes cleanly.

The interface is transmit-only by design - there is no MISO package pin and
chip_top_full ties the SPI miso input low - so no receive behaviour is tested.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

CLK_DIV = 4       # block Makefile default


async def reset(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0; dut.PENABLE.value = 0; dut.PWRITE.value = 0
    dut.PADDR.value = 0; dut.PWDATA.value = 0
    if hasattr(dut, "miso"): dut.miso.value = 0
    await Timer(50, unit="ns")
    dut.PRESETn.value = 1
    for _ in range(5): await RisingEdge(dut.PCLK)


async def apb_write(dut, data):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1; dut.PWRITE.value = 1; dut.PWDATA.value = data
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0; dut.PENABLE.value = 0; dut.PWRITE.value = 0


@cocotb.test()
async def test_mode0_idle_polarity(dut):
    """Mode 0: SCLK idles LOW and CS idles HIGH (inactive)."""
    await reset(dut)
    for _ in range(20):
        await RisingEdge(dut.PCLK)
        assert int(dut.sclk.value) == 0, "SCLK must idle low in Mode 0"
        assert int(dut.cs_n.value) == 1, "CS must idle high (deselected)"
    dut._log.info("*** SPI Mode 0 idle polarity PASS ***")


@cocotb.test()
async def test_cs_frames_the_transfer(dut):
    """CS asserts for the whole transfer and releases at the end.

    A slave latches on the CS edges, so a CS that drops early or lingers
    corrupts the byte boundary.
    """
    await reset(dut)
    await apb_write(dut, 0xA5)

    for _ in range(200):
        await RisingEdge(dut.PCLK)
        if int(dut.cs_n.value) == 0: break
    else:
        assert False, "CS never asserted after a write"

    saw_sclk = False
    for _ in range(400):
        await RisingEdge(dut.PCLK)
        if int(dut.sclk.value) == 1: saw_sclk = True
        if int(dut.cs_n.value) == 1: break
    assert saw_sclk, "SCLK never toggled while CS was low"

    for _ in range(20):
        await RisingEdge(dut.PCLK)
        assert int(dut.cs_n.value) == 1, "CS must stay high after the transfer"
        assert int(dut.sclk.value) == 0, "SCLK must return to idle low"
    dut._log.info("*** SPI CS framing PASS ***")


@cocotb.test()
async def test_mosi_is_msb_first(dut):
    """MOSI presents bits most-significant first, sampled on the rising edge.

    Sending 0x80 means MOSI must be high for the first bit; 0x01 means it must
    be low. That distinguishes MSB-first from LSB-first, which counting edges
    cannot.
    """
    for byte, first_bit in ((0x80, 1), (0x01, 0)):
        await reset(dut)
        await apb_write(dut, byte)

        for _ in range(200):
            await RisingEdge(dut.PCLK)
            if int(dut.cs_n.value) == 0: break

        prev = int(dut.sclk.value)
        for _ in range(400):
            await RisingEdge(dut.PCLK)
            cur = int(dut.sclk.value)
            if prev == 0 and cur == 1:
                assert int(dut.mosi.value) == first_bit, \
                    f"byte {byte:#04x}: first MOSI bit should be {first_bit}"
                break
            prev = cur
        else:
            assert False, f"no rising SCLK edge seen for {byte:#04x}"
    dut._log.info("*** SPI MSB-first PASS ***")


@cocotb.test()
async def test_eight_sclk_pulses_per_byte(dut):
    """Exactly eight SCLK rising edges per byte - no more, no fewer.

    A ninth edge would shift an extra bit into the slave; a missing one would
    truncate the byte.
    """
    await reset(dut)
    await apb_write(dut, 0x5A)

    # Count from BEFORE cs asserts, so an edge coincident with the CS drop is
    # not missed. Idle SCLK is low, so no spurious rises are added.
    # Count for a fixed window rather than stopping on CS: the eighth rising
    # edge and the CS release occur within a couple of cycles of each other,
    # so breaking on CS can miss the last pulse.
    rises, prev, idle_after_cs = 0, int(dut.sclk.value), 0
    for _ in range(600):
        await RisingEdge(dut.PCLK)
        cur = int(dut.sclk.value)
        if prev == 0 and cur == 1: rises += 1
        prev = cur
        if int(dut.cs_n.value) == 1:
            idle_after_cs += 1
            if idle_after_cs > 20: break

    assert rises == 8, f"expected 8 SCLK rising edges per byte, counted {rises}"
    dut._log.info("*** SPI 8 pulses per byte PASS ***")
