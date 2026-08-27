"""AHB routing SCOREBOARD -- randomized traffic, every cycle checked.

The sweep test proves directed decode at boundaries. This test proves there is
NO MISROUTING under randomized traffic: a software model predicts, every
transaction, (a) the one-hot HSEL and (b) which slave's response the registered
mux must return one cycle later; a passive checker compares the DUT against the
model on every access. 200 randomized transactions with random regions, offsets,
back-to-back bursts and idle gaps.

DUT: rtl/ahb_interconnect.sv (region = HADDR[17:16], response mux on region_q).
"""
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tb.coverage.memory_map_cov import MemoryMapCoverage, REGIONS, region_of

NONSEQ = 0b10
IDLE = 0b00
SENTINEL = {0: 0xA5A50000, 1: 0xB6B60001, 2: 0xC7C70002, 3: 0xD8D80003}
N_TXN = 200


async def init(dut):
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


def rand_addr(rng):
    rid = rng.randrange(4)
    _n, base, last = REGIONS[rid]
    off = rng.choice([0, last, rng.randrange(last + 1), last + rng.randrange(1, 16)])
    return base + off, rid


async def _routing_run(dut, seed, stall=False):
    rng = random.Random(seed)
    await init(dut)
    cov = MemoryMapCoverage()
    checked = 0
    model_region_q = 0          # region_q resets to 0; updates on active edges
    prev_active_region = None   # region of last ACTIVE cycle

    for _ in range(N_TXN):
        addr, rid = rand_addr(rng)
        dut.HADDR.value = addr
        dut.HTRANS.value = NONSEQ
        await RisingEdge(dut.HCLK)

        # combinational decode check: one-hot to the model's region
        hsel = int(dut.HSEL.value)
        assert hsel == (1 << rid), \
            f"MISROUTE: addr=0x{addr:08x} HSEL=0b{hsel:04b} expected bit {rid}"

        # registered response-mux check: HRDATA visible at this point still
        # reflects region_q BEFORE this edge (the previous active region;
        # 0 out of reset). The value we just latched becomes visible next read.
        rdata = int(dut.HRDATA.value)
        assert rdata == SENTINEL[model_region_q], \
            f"MUX MISROUTE: model region_q={model_region_q} " \
            f"HRDATA=0x{rdata:08x} expected 0x{SENTINEL[model_region_q]:08x}"
        model_region_q = rid          # latched at the edge we just took

        cov.sample(addr)
        checked += 1
        prev_active_region = rid

        # random idle gap (0-3 cycles); during idle HSEL must drop to 0 and the
        # response mux must keep returning the LAST active region's slave
        # (region_q only updates on active address phases -- documents the
        # as-built behavior the original code relies on)
        for _ in range(rng.randrange(4)):
            dut.HTRANS.value = IDLE
            await RisingEdge(dut.HCLK)
            assert int(dut.HSEL.value) == 0, "HSEL must be 0 during IDLE"
            rdata = int(dut.HRDATA.value)
            assert rdata == SENTINEL[model_region_q], \
                f"IDLE mux drift: HRDATA=0x{rdata:08x}, expected region_q " \
                f"{model_region_q}"

        # optional random slave stalls: drop a random slave's HREADY for a
        # few cycles; muxed HREADY must mirror region_q's slave exactly
        if stall and rng.random() < 0.3:
            victim = rng.randrange(4)
            getattr(dut, f"s{victim}_HREADY").value = 0
            dut.HTRANS.value = IDLE
            for _ in range(rng.randrange(1, 4)):
                await RisingEdge(dut.HCLK)
                exp = 0 if model_region_q == victim else 1
                got = int(dut.HREADY.value)
                assert got == exp, \
                    f"HREADY mux: region_q={model_region_q} victim={victim} " \
                    f"got {got} exp {exp}"
            getattr(dut, f"s{victim}_HREADY").value = 1

    cov.check_required()
    cocotb.log.info(f"*** routing seed={hex(seed)} stall={stall}: {checked} "
                    f"txns, zero misroutes ***")


@cocotb.test()
async def test_ahb_routing_scoreboard(dut):
    await _routing_run(dut, 0xC0FFEE)


@cocotb.test()
async def test_ahb_routing_multiseed_stall(dut):
    for seed in (0xBEEF01, 0xBEEF02, 0xBEEF03):
        await _routing_run(dut, seed, stall=True)
