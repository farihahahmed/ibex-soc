import os
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.sequences.random_spi_seq import RandomSpiTxSeq
from tb import dut_handle
from common import init_dut
from tb.coverage import cov

class PyuvmRandomSpiTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        seed = int(os.environ.get("RANDOM_SEED", "42"))
        seq = RandomSpiTxSeq("rs", seed=seed)
        expected = seq.byte
        self.env.scoreboard.expected_spi = expected
        self.env.scoreboard.require_events = {
            "program_loaded", "cpu_started", "spi_activity"
        }
        await seq.start(self.env.scan_agent.sequencer)
        await Timer(50000, unit="ns")
        self.logger.info(f"seed={seed} expected SPI=0x{expected:02x}")
        # Soft check: at least one SPI byte observed
        n = len(getattr(self.env.scoreboard, "seen_spi", []) or [])
        self.logger.info(f"SPI bytes seen: {n}")
        assert n >= 1, "No SPI activity"
        cov.report()
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_random_spi(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmRandomSpiTest")
