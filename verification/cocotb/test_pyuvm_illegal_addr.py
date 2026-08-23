"""Stress: store past dmem end (0x80), then legal GPIO write — must not hang."""
import cocotb
from cocotb.triggers import RisingEdge
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.agents.scan import ScanItem
from tb import dut_handle
from common import init_dut

# lui a0,0x0; li t0,0xA5; sw t0,0x80(a0);  # past 64B dmem
# lui a1,0x10; li t1,0x15; sw t1,0(a1); j .
PROG = [
    0x00000537,  # lui a0, 0
    0x0A500293,  # li  t0, 0xA5
    0x08552023,  # sw  t0, 0x80(a0)
    0x000105B7,  # lui a1, 0x10
    0x01500313,  # li  t1, 0x15
    0x0065A023,  # sw  t1, 0(a1)
    0x0000006F,  # j   .
]

class PyuvmIllegalAddrTest(uvm_test):
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
        await self._scan(1, 0, 0x00010000)  # RUN

        for _ in range(200):
            await RisingEdge(dut.clk)

        mode = int(dut.u_fsm.mode_o.value)
        gpio = int(dut.gpio_out.value) & 0x1F
        self.logger.info(f"mode={mode} gpio=0x{gpio:02x}")
        assert mode == 1, f"hung/left RUN? mode={mode}"
        assert gpio == 0x15, f"legal GPIO after OOB store failed: 0x{gpio:02x}"
        self.logger.info("*** illegal-addr stress PASS (no hang, GPIO ok) ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_illegal_addr(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmIllegalAddrTest")
