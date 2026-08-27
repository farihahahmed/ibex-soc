import os
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import PicoSocEnv
from tb.sequences.random_uart_seq import RandomUartTxSeq
from tb import dut_handle
from common import init_dut
from tb.coverage import cov

class PyuvmRandomUartTest(uvm_test):
    def build_phase(self):
        self.env = PicoSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        seed = int(os.environ.get("RANDOM_SEED", "42"))
        seq = RandomUartTxSeq("ru", seed=seed)
        expected = seq.bytes[0]
        self.env.scoreboard.expected_uart = expected
        self.env.scoreboard.require_events = {
            "program_loaded", "cpu_started", "uart_matched"
        }
        await seq.start(self.env.scan_agent.sequencer)
        await Timer(50000, unit="ns")
        self.logger.info(f"seed={seed} expected UART=0x{expected:02x}")
        cov.report()
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_random_uart(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmRandomUartTest")
