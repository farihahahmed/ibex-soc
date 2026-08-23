"""FSM COUNTDOWN: mode=2, count expires, run_gate drops."""
import cocotb
from cocotb.triggers import Timer, RisingEdge
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.agents.scan import ScanItem
from tb import dut_handle
from common import init_dut

class PyuvmCountdownTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def _scan(self, tgt, addr, data):
        item = ScanItem(f"t{tgt}", tgt=tgt, addr=addr, data=data)
        await self.env.scan_agent.sequencer.start_item(item)
        await self.env.scan_agent.sequencer.finish_item(item)

    async def run_phase(self):
        self.raise_objection()
        self.env.scoreboard.require_events = set()
        dut = dut_handle.DUT

        await Timer(200, unit="ns")
        assert int(dut.u_fsm.mode_o.value) == 0

        await self._scan(1, 0, (2 << 16) | 8)  # COUNTDOWN, count=8
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        mode = int(dut.u_fsm.mode_o.value)
        gate = int(dut.u_fsm.run_gate.value)
        count = int(dut.u_fsm.count.value)
        self.logger.info(f"early: mode={mode} gate={gate} count={count}")
        assert mode == 2
        assert gate == 1, "run_gate must be 1 while count>0"
        assert count > 0

        # Wait until count hits 0
        for _ in range(40):
            await RisingEdge(dut.clk)
            if int(dut.u_fsm.count.value) == 0:
                break

        # One more cycle for run_gate_q to follow
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        mode2 = int(dut.u_fsm.mode_o.value)
        gate2 = int(dut.u_fsm.run_gate.value)
        gate_q = int(dut.u_fsm.run_gate_q.value)
        count2 = int(dut.u_fsm.count.value)
        self.logger.info(f"late: mode={mode2} gate={gate2} gate_q={gate_q} count={count2}")
        assert mode2 == 2, "mode stays COUNTDOWN"
        assert count2 == 0
        assert gate2 == 0, "run_gate must be 0 when count==0"
        assert gate_q == 0, "run_gate_q must clear after count expires"

        self.logger.info("*** countdown PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_countdown(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmCountdownTest")
