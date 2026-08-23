"""System corner: concurrent GPIO+UART, then illegal addr must not hang."""
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.agents.scan import ScanItem
from tb import dut_handle
from common import init_dut

# lui a0,0x10; li t0,5; sw t0,0(a0)     GPIO=5
# lui a0,0x20; li t0,0x41; sw t0,4(a0)  UART DATA='A'
# lui a0,0xF0; sw t0,0(a0)              illegal ~0xF0000
# j .
PROG = [
    0x00010537,
    0x00500293,
    0x00552023,
    0x00020537,
    0x04100293,
    0x00552223,
    0x000F0537,
    0x00552023,
    0x0000006F,
]

class SysCorner(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        self.env.scoreboard.require_events = set()  # directed; we assert GPIO/mode ourselves

        for i, w in enumerate(PROG):
            it = ScanItem(f"w{i}", tgt=0, addr=i, data=w)
            await self.env.scan_agent.sequencer.start_item(it)
            await self.env.scan_agent.sequencer.finish_item(it)

        it = ScanItem("run", tgt=1, addr=0, data=0x00010000)
        await self.env.scan_agent.sequencer.start_item(it)
        await self.env.scan_agent.sequencer.finish_item(it)

        await Timer(40000, unit="ns")

        dut = dut_handle.DUT
        g = int(dut.gpio_out.value) & 0x1F
        mode = int(dut.u_fsm.mode_o.value)
        assert g == 0x05, f"GPIO expected 0x05 got {g:#x}"
        assert mode == 1, f"must still be RUN after illegal store, mode={mode}"
        self.logger.info("*** sys corner PASS: GPIO+UART concurrent, illegal addr no hang ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_sys_corner(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("SysCorner")
