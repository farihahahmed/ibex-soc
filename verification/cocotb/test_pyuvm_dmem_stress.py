"""Narrow dmem: SB + LBU paths; XOR result on GPIO."""
import cocotb
from cocotb.triggers import RisingEdge
from pyuvm import uvm_test, uvm_root
from tb.env import PicoSocEnv
from tb.agents.scan import ScanItem
from tb import dut_handle
from common import init_dut

PROG = [
    0x01000513,  # addi a0, x0, 0x10
    0x0A100293,  # li   t0, 0xA1
    0x00550023,  # sb   t0, 0(a0)
    0x0B200293,  # li   t0, 0xB2
    0x005500A3,  # sb   t0, 1(a0)
    0x00054583,  # lbu  a1, 0(a0)
    0x00154603,  # lbu  a2, 1(a0)
    0x00C5C5B3,  # xor  a1, a1, a2   # 0xA1^0xB2 = 0x13
    0x00010537,  # lui  a0, 0x10
    0x00B52023,  # sw   a1, 0(a0)
    0x0000006F,  # j    .
]

class PyuvmDmemStressTest(uvm_test):
    def build_phase(self):
        self.env = PicoSocEnv.create("env", self)

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
        await self._scan(1, 0, 0x00010000)

        for _ in range(400):
            await RisingEdge(dut.clk)

        gpio = int(dut.gpio_out.value) & 0x1F
        mode = int(dut.u_fsm.mode_o.value)
        self.logger.info(f"mode={mode} gpio=0x{gpio:02x} (expect 0x13)")
        assert mode == 1
        assert gpio == 0x13, f"byte path failed gpio=0x{gpio:02x}"
        self.logger.info("*** dmem stress PASS (SB/LBU + XOR) ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_dmem_stress(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmDmemStressTest")
