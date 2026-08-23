import os
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.sequences.random_scan_seq import RandomScanSeq
from tb import dut_handle
from common import init_dut

class PyuvmRandomTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        seed = int(os.environ.get("RANDOM_SEED", "42"))
        seq = RandomScanSeq("rand", seed=seed, n_extra=4)
        await seq.start(self.env.scan_agent.sequencer)

        self.env.scoreboard.expected_gpio = seq.chosen_val
        self.env.scoreboard.expected_uart = None
        self.env.scoreboard.require_events = {
            "program_loaded", "cpu_started", "gpio_matched"
        }

        await Timer(15000, unit="ns")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_random(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmRandomTest")
