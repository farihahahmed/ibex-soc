"""CRC32 PCPI accelerator: end-to-end proof.

crc_demo.bin folds the standard check vector "123456789" through the custom
crc32 instruction (custom-0, funct3=000, funct7=0000000) and prints the result
as hex over UART. cbf43926 is the published CRC32 check constant, so a match
proves the hardware agrees with an independent reference, not just our model.
"""
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import PicoSocEnv
from tb.sequences.firmware_seq import LoadFirmwareSeq
from tb import dut_handle
from common import init_dut

EXPECTED = "cbf43926"

class PyuvmCrcTest(uvm_test):
    def build_phase(self):
        self.env = PicoSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()

        seq = LoadFirmwareSeq("crc", "../../firmware/crc_demo.bin")
        await seq.start(self.env.scan_agent.sequencer)
        self.env.scoreboard.require_events = {"program_loaded", "cpu_started"}

        await Timer(500000, unit="ns")

        uart_bytes = self.env.scoreboard.seen_uart
        text = "".join(chr(b) for b in uart_bytes if 32 <= b < 127)
        self.logger.info(f"UART text: '{text}'")

        assert EXPECTED in text, \
            f"CRC32 accelerator wrong: expected '{EXPECTED}' in UART, got '{text}'"

        self.logger.info("*** CRC32 PCPI accelerator PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_crc(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmCrcTest")
