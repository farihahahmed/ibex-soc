"""All seven custom-0 PCPI instructions, executed through the CPU.

pcpi_demo.bin runs crc32.b, crc32.w, popcnt, brev, macclr, mac and macrd, and
prints each result as hex over UART. Expected values come from a Python model
of the same algorithms; the CRC constant cbf43926 is the published CRC32 check
value, so that one is checked against an independent reference rather than our
own model.

This complements the standalone module testbench: that proves the arithmetic,
this proves the instructions decode and write back correctly through PicoRV32.
"""
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import PicoSocEnv
from tb.sequences.firmware_seq import LoadFirmwareSeq
from tb import dut_handle
from common import init_dut

EXPECTED = ["cbf43926", "641c1f5c", "00000010", "f0000000", "0000006b", "0000006b"]

class PyuvmPcpiTest(uvm_test):
    def build_phase(self):
        self.env = PicoSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        seq = LoadFirmwareSeq("pcpi", "../../firmware/pcpi_demo.bin")
        await seq.start(self.env.scan_agent.sequencer)
        self.env.scoreboard.require_events = {"program_loaded", "cpu_started"}

        await Timer(600000, unit="ns")

        text = "".join(chr(b) for b in self.env.scoreboard.seen_uart if 32 <= b < 127)
        self.logger.info(f"UART text: '{text}'")

        names = ["crc32.b", "crc32.w", "popcnt", "brev", "mac", "macrd"]
        missing = [f"{n}={e}" for n, e in zip(names, EXPECTED) if e not in text]
        assert not missing, f"PCPI results missing from UART: {missing} - got '{text}'"

        self.logger.info("*** all 7 PCPI instructions PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_pcpi(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    from tb.coverage.fsm_cov import sample_fsms, fsm_cov
    cocotb.start_soon(sample_fsms(dut, dut.clk))
    await uvm_root().run_test("PyuvmPcpiTest")
    dut._log.info(fsm_cov.report())
    fsm_cov.persist()
