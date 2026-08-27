"""Directed dmem: SW then LW at addr 0x10, result to GPIO."""
import cocotb
from cocotb.triggers import RisingEdge
from pyuvm import uvm_test, uvm_root
from tb.env import PicoSocEnv
from tb.agents.scan import ScanItem
from tb.coverage import cov
from tb import dut_handle
from common import init_dut

# t0=0x10, t1=0x15, sw t1,0(t0); lw t2,0(t0); GPIO=t2
DMEM_PROG = [
    0x01000293,  # addi t0, x0, 16
    0x01500313,  # addi t1, x0, 0x15
    0x0062A023,  # sw   t1, 0(t0)
    0x0002A383,  # lw   t2, 0(t0)
    0x00010537,  # lui  a0, 0x10
    0x00752023,  # sw   t2, 0(a0)
    0x0000006F,  # j    .
]

class PyuvmDmemTest(uvm_test):
    def build_phase(self):
        self.env = PicoSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        expect = 0x15
        self.env.scoreboard.expected_gpio = expect
        self.env.scoreboard.require_events = {
            "program_loaded", "cpu_started", "gpio_matched"
        }

        for i, w in enumerate(DMEM_PROG):
            item = ScanItem(f"p{i}", tgt=0, addr=i, data=w)
            await self.env.scan_agent.sequencer.start_item(item)
            await self.env.scan_agent.sequencer.finish_item(item)
        cov.sample_event("program_loaded")

        item = ScanItem("clkgen", tgt=2, addr=0, data=0)
        await self.env.scan_agent.sequencer.start_item(item)
        await self.env.scan_agent.sequencer.finish_item(item)
        item = ScanItem("run", tgt=1, addr=0, data=0x00010000)
        await self.env.scan_agent.sequencer.start_item(item)
        await self.env.scan_agent.sequencer.finish_item(item)
        cov.sample_event("cpu_started")

        dut = dut_handle.DUT
        matched = False
        for _ in range(15000):
            await RisingEdge(dut.clk)
            try:
                g = int(dut.gpio_out.value) & 0x1F
            except Exception:
                g = -1
            if g == expect:
                matched = True
                break

        self.logger.info(f"dmem SW/LW -> GPIO=0x{int(dut.gpio_out.value)&0x1F:02x} expect=0x{expect:02x}")
        assert matched, "dmem load/store did not produce expected GPIO"
        cov.sample_event("gpio_matched")
        self.logger.info("*** pyuvm dmem PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_dmem(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmDmemTest")
