"""AHB fabric decode SWEEP + routing + coverage closure.

`test_ahb_decode` proves one address per region decodes to a one-hot HSEL.
This test goes further, matching the SoC-fabric decode-coverage item:

  * sweep low / mid / high of every mapped region (boundaries, not just base),
  * confirm HSEL stays one-hot and routes to the correct slave across the range
    (no misrouting anywhere in a region, not only at its base),
  * confirm the *registered* response mux (region_q) returns the selected
    slave's HRDATA/HREADY one cycle later,
  * drive an address past each region's populated tail (the "gap"), and
  * assert functional-coverage CLOSURE via MemoryMapCoverage.check_required().

DUT: rtl/ahb_interconnect.sv  (region = HADDR[17:16], active = HTRANS[1]).
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tb.coverage.memory_map_cov import MemoryMapCoverage, REGIONS, region_of

NONSEQ = 0b10
IDLE = 0b00

# unique sentinel read-data per slave, so a mux misroute is unambiguous
SENTINEL = {0: 0xA5A50000, 1: 0xB6B60001, 2: 0xC7C70002, 3: 0xD8D80003}


async def _init(dut):
    cocotb.start_soon(Clock(dut.HCLK, 10, unit="ns").start())
    dut.HRESETn.value = 0
    dut.HADDR.value = 0
    dut.HTRANS.value = 0
    dut.HWRITE.value = 0
    dut.HWDATA.value = 0
    for i in range(4):
        getattr(dut, f"s{i}_HRDATA").value = SENTINEL[i]
        getattr(dut, f"s{i}_HREADY").value = 1
        getattr(dut, f"s{i}_HRESP").value = 0
    for _ in range(4):
        await RisingEdge(dut.HCLK)
    dut.HRESETn.value = 1
    await RisingEdge(dut.HCLK)


def _sweep_addrs():
    """Yield (addr, region_id) for low/mid/high + one unmapped-gap per region."""
    for rid, (_name, base, last) in REGIONS.items():
        for off in (0, last // 2, last):          # low, mid, high (in-range)
            yield base + off, rid
        yield base + last + 1, rid                 # first gap address past tail


@cocotb.test()
async def test_ahb_decode_sweep(dut):
    await _init(dut)
    cov = MemoryMapCoverage()

    for addr, rid in _sweep_addrs():
        # ---- present the address phase ----
        dut.HADDR.value = addr
        dut.HTRANS.value = NONSEQ
        await RisingEdge(dut.HCLK)              # region_q latches this cycle

        # decode is combinational on the current address -> one-hot to region
        hsel = int(dut.HSEL.value)
        assert hsel == (1 << rid), (
            f"addr=0x{addr:08x} HSEL=0b{hsel:04b} expected one-hot bit {rid}"
        )
        assert bin(hsel).count("1") == 1, f"HSEL not one-hot: 0b{hsel:04b}"

        # hold the address one more cycle so the registered response mux
        # (keyed on region_q) is settled, then check it routed the right slave
        await RisingEdge(dut.HCLK)
        rdata = int(dut.HRDATA.value)
        assert rdata == SENTINEL[rid], (
            f"response mux misroute: region {rid} addr=0x{addr:08x} "
            f"HRDATA=0x{rdata:08x} expected 0x{SENTINEL[rid]:08x}"
        )

        cov.sample(addr)
        cocotb.log.info(
            f"addr=0x{addr:08x} region={rid} HSEL=0b{hsel:04b} "
            f"HRDATA=0x{rdata:08x} OK"
        )

    # ---- IDLE must clear the select (no phantom decode) ----
    dut.HTRANS.value = IDLE
    await RisingEdge(dut.HCLK)
    assert int(dut.HSEL.value) == 0, "HSEL must be 0 when HTRANS=IDLE"

    # ---- coverage closure: every region + every band must be hit ----
    cocotb.log.info(cov.report())
    cov.check_required()
    cocotb.log.info("*** ahb decode sweep + routing + coverage PASS ***")


@cocotb.test()
async def test_hresp_tied_zero(dut):
    """KNOWN_GAPS: HRESP is tied low everywhere -- assert it explicitly across
    every region and during idle, turning the limitation into a closed check."""
    await _init(dut)
    for rid, (_n, base, last) in REGIONS.items():
        dut.HADDR.value = base + (last // 2)
        dut.HTRANS.value = NONSEQ
        await RisingEdge(dut.HCLK)
        await RisingEdge(dut.HCLK)
        assert int(dut.HRESP.value) == 0, f"HRESP nonzero in region {rid}"
    dut.HTRANS.value = IDLE
    await RisingEdge(dut.HCLK)
    assert int(dut.HRESP.value) == 0, "HRESP nonzero at idle"
    cocotb.log.info("*** HRESP tied-0 everywhere PASS ***")


@cocotb.test()
async def test_unmapped_addresses_alias_not_error(dut):
    """KNOWN_GAPS: two decode bits -> no unmapped hole. Addresses past each
    region's populated tail ALIAS into the same region (HSEL still one-hot,
    HREADY=1, HRESP=0) rather than erroring. Named check for the doc claim."""
    await _init(dut)
    for rid, (_n, base, last) in REGIONS.items():
        for gap in (base + last + 1, base + 0xFFFF):
            dut.HADDR.value = gap
            dut.HTRANS.value = NONSEQ
            await RisingEdge(dut.HCLK)
            hsel = int(dut.HSEL.value)
            assert hsel == (1 << rid), \
                f"gap 0x{gap:08x} must alias to region {rid}, HSEL=0b{hsel:04b}"
            await RisingEdge(dut.HCLK)
            assert int(dut.HREADY.value) == 1 and int(dut.HRESP.value) == 0, \
                "aliased access must complete normally (no error response)"
    cocotb.log.info("*** unmapped-alias (no error) named check PASS ***")
