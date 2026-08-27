"""System corner: scan tgt decode + FSM mode."""
import cocotb
from cocotb.triggers import Timer, RisingEdge
from pyuvm import uvm_test, uvm_root
from tb.env import PicoSocEnv
from tb.agents.scan import ScanItem
from tb import dut_handle
from common import init_dut

class PyuvmScanCornersTest(uvm_test):
    def build_phase(self):
        self.env = PicoSocEnv.create("env", self)

    async def _scan(self, tgt, addr, data):
        item = ScanItem(f"t{tgt}_{addr:x}", tgt=tgt, addr=addr, data=data)
        await self.env.scan_agent.sequencer.start_item(item)
        await self.env.scan_agent.sequencer.finish_item(item)

    async def run_phase(self):
        self.raise_objection()
        self.env.scoreboard.require_events = set()
        dut = dut_handle.DUT

        await Timer(200, unit="ns")
        assert int(dut.u_fsm.mode_o.value) == 0

        # tgt=3 (MEMORY_READ) with RUN-looking data must not change mode
        await self._scan(3, 0, 0x00010000)
        for _ in range(20):
            await RisingEdge(dut.clk)
        assert int(dut.u_fsm.mode_o.value) == 0

        # Mem tgt=0 with RUN-looking data → IDLE
        await self._scan(0, 0, 0x00010000)
        for _ in range(20):
            await RisingEdge(dut.clk)
        assert int(dut.u_fsm.mode_o.value) == 0

        # Clkgen tgt=2 must not change FSM mode
        await self._scan(2, 0, 0x00010000)
        for _ in range(20):
            await RisingEdge(dut.clk)
        mode = int(dut.u_fsm.mode_o.value)
        self.logger.info(f"After tgt=2: mode={mode}")
        assert mode == 0, f"clkgen tgt must not set RUN, got {mode}"

        # Valid FSM tgt=1, data with mode=RUN in [17:16]
        await self._scan(1, 0, 0x00010000)
        for _ in range(20):
            await RisingEdge(dut.clk)
        mode = int(dut.u_fsm.mode_o.value)
        owns = int(dut.u_fsm.scan_owns_mem.value)
        self.logger.info(f"After valid RUN: mode={mode} owns={owns}")
        assert mode == 1, f"expected RUN mode=1, got {mode}"
        assert owns == 0, f"expected scan_owns_mem=0, got {owns}"

        self.logger.info("*** scan corners PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_scan_corners(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmScanCornersTest")
