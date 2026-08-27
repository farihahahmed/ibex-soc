import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import PicoSocEnv
from tb.sequences.firmware_seq import LoadFirmwareSeq
from tb import dut_handle
from common import init_dut

class PyuvmPrimesTest(uvm_test):
    def build_phase(self):
        self.env = PicoSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()

        seq = LoadFirmwareSeq("primes", "../../firmware/primes.bin")
        await seq.start(self.env.scan_agent.sequencer)
        self.env.scoreboard.require_events = {
            "program_loaded", "cpu_started"
        }

        # Wait for UART to print several primes
        await Timer(500000, unit="ns")

        # Check scoreboard saw digit '2' at least (0x32)
        uart_bytes = self.env.scoreboard.seen_uart
        text = "".join(chr(b) for b in uart_bytes if 32 <= b < 127)
        self.logger.info(f"UART text: '{text}'")

        assert "2" in text and "3" in text and "5" in text, \
            f"Expected primes in UART, got '{text}'"

        self.logger.info("*** pyuvm primes PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_primes(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    # FSM state and arc coverage, sampled for the whole run
    from tb.coverage.fsm_cov import sample_fsms, fsm_cov
    cocotb.start_soon(sample_fsms(dut, dut.clk))
    await uvm_root().run_test("PyuvmPrimesTest")
    dut._log.info(fsm_cov.report())
    fsm_cov.persist()
