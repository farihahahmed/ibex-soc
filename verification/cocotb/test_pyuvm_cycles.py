"""Cycle-count comparison: custom instructions vs their software equivalents.

PicoRV32 is built with ENABLE_COUNTERS=0, so there is no cycle counter to read
from firmware. Instead cycles_demo.c raises GPIO[4] around each measured region
and this test counts clock edges while it is high. Four regions run in order:

    1. CRC32 over 8 bytes, software (bitwise loop)
    2. CRC32 over 8 bytes, custom crc32.b instruction
    3. popcount over 8 words, software
    4. popcount over 8 words, custom popcnt instruction

Both halves of each pair process identical data, so the ratio is the speedup.
The software CRC is the bitwise loop rather than a table lookup because the
1 KB table a table-driven CRC needs does not fit in this chip's 512 B of data
memory - so this is the realistic baseline, not a strawman.
"""
import cocotb
from cocotb.triggers import RisingEdge, Timer
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.sequences.firmware_seq import LoadFirmwareSeq
from tb import dut_handle
from common import init_dut

MARK_BIT = 4          # GPIO[4]


class PyuvmCyclesTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        seq = LoadFirmwareSeq("cycles", "../../firmware/cycles_demo.bin")
        await seq.start(self.env.scan_agent.sequencer)
        self.env.scoreboard.require_events = {"program_loaded", "cpu_started"}

        dut = dut_handle.DUT
        regions, count, prev, seen = [], 0, 0, 0

        # Sample the marker for long enough to catch all four regions.
        for _ in range(400000):
            await RisingEdge(dut.clk)
            cur = (int(dut.gpio_out.value) >> MARK_BIT) & 1
            if cur:
                count += 1
            elif prev and count:
                regions.append(count)
                count, seen = 0, seen + 1
                if seen == 4:
                    break
            prev = cur

        self.logger.info(f"raw regions seen: {regions}")
        self.logger.info(f"total sampled cycles: {sum(regions)}")
        assert len(regions) == 4, \
            f"expected 4 measured regions, saw {len(regions)}: {regions}"

        crc_sw, crc_hw, pop_sw, pop_hw = regions
        self.logger.info("")
        self.logger.info("  operation          software   hardware   speedup")
        self.logger.info(f"  CRC32 x8 bytes     {crc_sw:8d}   {crc_hw:8d}   "
                         f"{crc_sw/crc_hw:6.2f}x")
        self.logger.info(f"  popcount x8 words  {pop_sw:8d}   {pop_hw:8d}   "
                         f"{pop_sw/pop_hw:6.2f}x")
        self.logger.info("")

        assert crc_hw < crc_sw, \
            f"hardware CRC ({crc_hw}) should beat software ({crc_sw})"
        assert pop_hw < pop_sw, \
            f"hardware popcount ({pop_hw}) should beat software ({pop_sw})"

        self.logger.info("*** PCPI cycle comparison PASS ***")
        self.drop_objection()


@cocotb.test()
async def test_pyuvm_cycles(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmCyclesTest")
