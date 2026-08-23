"""B1: wrong expected GPIO must FAIL (proves scoreboard is not always-pass)."""
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.sequences.firmware_seq import LoadFirmwareSeq
from tb import dut_handle
from common import init_dut

# Same tiny program as smoke: writes GPIO 0x05
SMOKE_PROG = [
    0x00010537, 0x000205B7, 0x00030637,
    0x0A500293, 0x04100313, 0x0B700393,
    0x00552023, 0x0065A023, 0x00762023,
    0x00000013, 0xFFDFF06F,
]

class PyuvmNegGpioTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        # Intentionally WRONG expect (DUT will drive 0x05)
        self.env.scoreboard.expected_gpio = 0x1A
        self.env.scoreboard.require_events = {"program_loaded", "cpu_started"}

        from tb.agents.scan import ScanItem
        for i, w in enumerate(SMOKE_PROG):
            item = ScanItem(f"w{i}", tgt=0, addr=i, data=w)
            await self.env.scan_agent.sequencer.start_item(item)
            await self.env.scan_agent.sequencer.finish_item(item)
        # start RUN
        item = ScanItem("run", tgt=1, addr=0, data=0x00010000)
        await self.env.scan_agent.sequencer.start_item(item)
        await self.env.scan_agent.sequencer.finish_item(item)

        await Timer(30000, unit="ns")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_neg_gpio(dut):
    from common import init_dut
    from tb import dut_handle
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmNegGpioTest")
