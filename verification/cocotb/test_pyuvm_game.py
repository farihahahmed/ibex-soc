import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.sequences.firmware_seq import LoadFirmwareSeq
from tb import dut_handle
from common import init_dut

class PyuvmGameTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()

        seq = LoadFirmwareSeq("game", "../../firmware/game.bin")
        await seq.start(self.env.scan_agent.sequencer)
        self.env.scoreboard.require_events = {
            "program_loaded", "cpu_started", "spi_activity"
        }

        await Timer(500000, unit="ns")

        n = len(self.env.scoreboard.seen_spi)
        self.logger.info(f"SPI bytes observed: {n}")
        assert n > 10, f"Expected SPI activity, got {n} bytes"
        self.logger.info("*** pyuvm game PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_game(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmGameTest")
