import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.sequences.scan_seq import LoadProgramSeq, StartCpuSeq
from tb import dut_handle
from common import init_dut

PROG = [
    0x00010537, 0x000205B7, 0x00030637,
    0x0A500293, 0x04100313, 0x0B700393,
    0x00552023, 0x0065A023, 0x00762023,
    0x00000013, 0xFFDFF06F,
    0x00000013, 0x00000013, 0x00000013, 0x00000013, 0x00000013,
]

class PyuvmSmokeTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        self.env.scoreboard.expected_gpio = 0x05
        self.env.scoreboard.expected_uart = 0x41
        self.env.scoreboard.require_events = {
            "program_loaded", "cpu_started", "gpio_matched", "uart_matched"
        }

        seq = LoadProgramSeq("load", PROG)
        await seq.start(self.env.scan_agent.sequencer)
        start = StartCpuSeq("start")
        await start.start(self.env.scan_agent.sequencer)

        await Timer(20000, unit="ns")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_smoke(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    # Shared bus UVC: same ApbMonitor as block tests
    from tb.agents.apb import dut_handle as apb_dh, ApbIf
    apb_dh.IF = ApbIf.from_chip(dut)
    await uvm_root().run_test("PyuvmSmokeTest")
