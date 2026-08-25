"""Scan corner: invalid tgt must not enter RUN; valid RUN still works after."""
import cocotb
from cocotb.triggers import Timer, RisingEdge
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.agents.scan import ScanItem
from tb import dut_handle
from common import init_dut

class ScanCorner(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)
    async def run_phase(self):
        self.raise_objection()
        self.env.scoreboard.require_events = set()  # no FW
        # tgt=3 is MEMORY_READ: must not disturb the FSM mode
        it = ScanItem("bad", tgt=3, addr=0, data=0xDEAD)
        await self.env.scan_agent.sequencer.start_item(it)
        await self.env.scan_agent.sequencer.finish_item(it)
        await Timer(500, unit="ns")
        mode = int(dut_handle.DUT.u_fsm.mode_o.value)
        assert mode == 0, f"illegal tgt must leave IDLE, mode={mode}"
        # valid RUN
        it = ScanItem("run", tgt=1, addr=0, data=0x00010000)
        await self.env.scan_agent.sequencer.start_item(it)
        await self.env.scan_agent.sequencer.finish_item(it)
        await Timer(500, unit="ns")
        mode = int(dut_handle.DUT.u_fsm.mode_o.value)
        assert mode == 1, f"RUN failed mode={mode}"
        self.logger.info("*** scan corner PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_scan_corner(dut):
    await init_dut(dut)
    from tb import dut_handle as dh
    dh.DUT = dut
    await uvm_root().run_test("ScanCorner")
