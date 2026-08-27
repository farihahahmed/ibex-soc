"""Scoreboard self-check: a deliberately wrong GPIO expectation must be caught.

This is a test of the testbench, not of the DUT. It answers the question a
reviewer should ask - how do you know the scoreboard is not always green?
Marked expect_fail, so it passes only when the checker correctly reports the
mismatch."""
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import PicoSocEnv
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
        self.env = PicoSocEnv.create("env", self)

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

# expect_fail: this test SHOULD fail. It deliberately tells the scoreboard to
# expect GPIO 0x1A when the DUT drives 0x05, so a failure proves the scoreboard
# actually compares values rather than passing everything. cocotb inverts the
# verdict, so the gate sees a pass when the checker correctly catches the
# mismatch - and would see a FAILURE if the scoreboard ever went always-green.
@cocotb.test(expect_fail=True)
async def test_pyuvm_neg_gpio(dut):
    from common import init_dut
    from tb import dut_handle
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmNegGpioTest")
