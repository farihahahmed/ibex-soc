import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, ConfigDB, uvm_root
from tb.env import IbexSocEnv
from tb.sequences.scan_seq import LoadProgramSeq, StartCpuSeq
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
        dut = ConfigDB().get(None, "", "DUT")

        seq = LoadProgramSeq("load", PROG)
        await seq.start(self.env.scan_agent.sequencer)

        start = StartCpuSeq("start")
        await start.start(self.env.scan_agent.sequencer)

        await Timer(20000, unit="ns")

        gpio = int(dut.gpio_out.value) & 0x1F
        assert gpio == 0x05, f"GPIO expected 0x05, got 0x{gpio:02x}"
        self.logger.info("*** pyuvm smoke PASS: GPIO=0x05 ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_smoke(dut):
    await init_dut(dut)
    ConfigDB().set(None, "*", "DUT", dut)
    await uvm_root().run_test("PyuvmSmokeTest")
