"""Corner: IDLE→RUN→IDLE→RUN recovery (scan FSM only; no mid-cycle rst_n)."""
import cocotb
from cocotb.triggers import Timer, RisingEdge
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.agents.scan import ScanItem
from tb import dut_handle
from common import init_dut

# lui a0,0x10; li t0,0x15; sw t0,0(a0); j .
PROG = [
    0x00010537,
    0x01500293,
    0x00552023,
    0x0000006F,
]

class PyuvmRerunTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def _scan(self, tgt, addr, data):
        item = ScanItem(f"s{tgt}_{addr}", tgt=tgt, addr=addr, data=data)
        await self.env.scan_agent.sequencer.start_item(item)
        await self.env.scan_agent.sequencer.finish_item(item)

    async def run_phase(self):
        self.raise_objection()
        self.env.scoreboard.require_events = set()
        dut = dut_handle.DUT

        for i, w in enumerate(PROG):
            await self._scan(0, i, w)

        # RUN
        await self._scan(1, 0, 0x00010000)
        for _ in range(40):
            await RisingEdge(dut.clk)
        mode = int(dut.u_fsm.mode_o.value)
        assert mode == 1, f"first RUN failed mode={mode}"
        g1 = int(dut.gpio_out.value) & 0x1F
        self.logger.info(f"after RUN1: mode={mode} gpio=0x{g1:02x}")

        # back to IDLE
        await self._scan(1, 0, 0x00000000)
        for _ in range(20):
            await RisingEdge(dut.clk)
        mode = int(dut.u_fsm.mode_o.value)
        owns = int(dut.u_fsm.scan_owns_mem.value)
        assert mode == 0, f"IDLE failed mode={mode}"
        assert owns == 1, f"scan_owns_mem expected 1, got {owns}"
        self.logger.info(f"after IDLE: mode={mode} owns={owns}")

        # RUN again (image still in imem)
        await self._scan(1, 0, 0x00010000)
        for _ in range(80):
            await RisingEdge(dut.clk)
        mode = int(dut.u_fsm.mode_o.value)
        g2 = int(dut.gpio_out.value) & 0x1F
        self.logger.info(f"after RUN2: mode={mode} gpio=0x{g2:02x}")
        assert mode == 1, f"second RUN failed mode={mode}"
        assert g2 == 0x15, f"expected GPIO 0x15 after re-RUN, got 0x{g2:02x}"

        self.logger.info("*** re-RUN PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_rerun(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmRerunTest")
