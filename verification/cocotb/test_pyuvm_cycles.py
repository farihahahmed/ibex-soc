"""Cycle-count comparison: custom CRC32 instruction vs the software loop.

PicoRV32 is built with ENABLE_COUNTERS=0, so there is no cycle counter to read
from firmware. cycles_min.c raises GPIO[4] around each measured region and this
test counts clock edges while it is high.

Both regions fold 64 bytes through CRC32 over identical data:
    region 1 - software, bitwise loop, ~3,840 instructions
    region 2 - custom crc32.b instruction, ~192 instructions

The software version is the bitwise loop rather than a table lookup, because
the 1 KB table a table-driven CRC needs does not fit in this chip's 512 B of
data memory. So it is the realistic baseline, not a strawman.
"""
import cocotb
from cocotb.triggers import RisingEdge
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.sequences.firmware_seq import LoadFirmwareSeq
from tb import dut_handle
from common import init_dut

MARK_BIT = 4


class PyuvmCyclesTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        seq = LoadFirmwareSeq("cycles", "../../firmware/cycles_min.bin")
        await seq.start(self.env.scan_agent.sequencer)
        self.env.scoreboard.require_events = {"program_loaded", "cpu_started"}

        dut = dut_handle.DUT
        regions, count, prev, seen = [], 0, 0, 0
        for _ in range(2000000):
            await RisingEdge(dut.clk)
            cur = (int(dut.gpio_out.value) >> MARK_BIT) & 1
            if cur:
                count += 1
            elif prev and count:
                regions.append(count); count = 0; seen += 1
                if seen == 2:
                    break
            prev = cur

        self.logger.info(f"raw regions: {regions}")
        assert len(regions) >= 2, f"expected 2 regions, saw {regions}"

        sw, hw = regions[0], regions[1]
        self.logger.info("")
        self.logger.info("  CRC32 over 64 bytes    cycles")
        self.logger.info(f"    software (bitwise)   {sw:8d}")
        self.logger.info(f"    custom instruction   {hw:8d}")
        self.logger.info(f"    speedup              {sw/hw:7.2f}x")
        self.logger.info("")

        assert hw < sw, f"hardware ({hw}) should beat software ({sw})"
        self.logger.info("*** PCPI cycle comparison PASS ***")
        self.drop_objection()


@cocotb.test()
async def test_pyuvm_cycles(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmCyclesTest")
