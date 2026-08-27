"""Negative: while RUN, scan mem writes must not change running program behavior."""
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import PicoSocEnv
from tb.agents.scan import ScanItem
from tb import dut_handle
from common import init_dut

def gpio_prog(val):
    imm = val & 0x1F
    return [
        0x00010537,                      # lui a0, 0x10
        0x00000093 | ((imm & 0xFFF) << 20),  # li t0, imm
        0x00152023,                      # sw t0, 0(a0)
        0x00000013,                      # nop
        0xFFDFF06F,                      # j .
    ]

class PyuvmScanLockoutTest(uvm_test):
    def build_phase(self):
        self.env = PicoSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        self.env.scoreboard.require_events = set()

        # 1) load GPIO=0x15
        for i, w in enumerate(gpio_prog(0x15)):
            item = ScanItem(f"a{i}", tgt=0, addr=i, data=w)
            await self.env.scan_agent.sequencer.start_item(item)
            await self.env.scan_agent.sequencer.finish_item(item)

        # RUN
        item = ScanItem("run", tgt=1, addr=0, data=0x00010000)
        await self.env.scan_agent.sequencer.start_item(item)
        await self.env.scan_agent.sequencer.finish_item(item)

        dut = dut_handle.DUT
        await Timer(12000, unit="ns")
        g1 = int(dut.gpio_out.value) & 0x1F
        owns = int(dut.u_fsm.scan_owns_mem.value)
        mode = int(dut.u_fsm.mode_o.value)
        self.logger.info(f"after RUN: GPIO=0x{g1:02x} mode={mode} owns={owns}")
        assert mode == 1 and owns == 0
        assert g1 == 0x15, f"expected 0x15 got 0x{g1:02x}"

        # 2) try to overwrite with GPIO=0x0A while RUN (must be ignored)
        for i, w in enumerate(gpio_prog(0x0A)):
            item = ScanItem(f"b{i}", tgt=0, addr=i, data=w)
            await self.env.scan_agent.sequencer.start_item(item)
            await self.env.scan_agent.sequencer.finish_item(item)

        await Timer(12000, unit="ns")
        g2 = int(dut.gpio_out.value) & 0x1F
        owns2 = int(dut.u_fsm.scan_owns_mem.value)
        self.logger.info(f"after overwrite attempt: GPIO=0x{g2:02x} owns={owns2}")
        assert owns2 == 0
        assert g2 == 0x15, f"scan corrupted running image: got 0x{g2:02x}"
        self.logger.info("*** scan lockout (negative) PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_scan_lockout(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmScanLockoutTest")
