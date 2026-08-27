"""imem: scan-style ld_word → 4-byte write → CPU-style fetch readback."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

def _ri(sig):
    """Resolved int, or None if the signal is still X/Z."""
    v = sig.value
    return int(v) if v.is_resolvable else None


@cocotb.test()
async def test_imem_load(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.req.value = 0
    dut.addr.value = 0
    dut.ld_word_en.value = 0
    dut.scan_owns.value = 1   # scan owns during load
    dut.ld_word_addr.value = 0
    dut.ld_word_data.value = 0
    for _ in range(4):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(6):
        await RisingEdge(dut.clk)

    word = 0xDEADBEEF
    # pulse load one cycle
    dut.ld_word_addr.value = 0
    dut.ld_word_data.value = word
    dut.ld_word_en.value = 1
    await RisingEdge(dut.clk)
    dut.ld_word_en.value = 0
    dut.scan_owns.value = 1   # scan owns during load

    # wait scatter done
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.ld_busy.value.is_resolvable and int(dut.ld_busy.value) == 0:
            break
    assert dut.ld_busy.value.is_resolvable and int(dut.ld_busy.value) == 0, \
        "ld_busy stuck or unresolved"

    # fetch word 0 (CPU owns the port now)
    dut.scan_owns.value = 0
    await RisingEdge(dut.clk)
    dut.addr.value = 0
    dut.req.value = 1
    got_gnt = False
    for _ in range(20):
        await RisingEdge(dut.clk)
        if _ri(dut.gnt) == 1:
            got_gnt = True
            dut.req.value = 0
            break
    assert got_gnt, "no gnt on fetch"

    rdata = None
    for _ in range(30):
        await RisingEdge(dut.clk)
        if int(dut.rvalid.value):
            rdata = int(dut.rdata.value)
            break
    assert rdata is not None, "no rvalid"
    cocotb.log.info(f"loaded 0x{word:08x} fetched 0x{rdata:08x}")
    assert rdata == word, f"mismatch got 0x{rdata:08x}"
    cocotb.log.info("*** imem load PASS ***")
