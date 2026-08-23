"""System corner: GPIO + UART + SPI in one scan-loaded program."""
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.agents.scan import ScanItem
from tb.coverage import cov
from tb import dut_handle
from common import init_dut

# Same directed image as tb_chip_v2 / smoke (GPIO=0x05, UART=0x41, SPI=0xB7)
PROG = [
    0x00010537, 0x000205B7, 0x00030637,
    0x0A500293, 0x04100313, 0x0B700393,
    0x00552023, 0x0065A023, 0x00762023,
    0x00000013, 0xFFDFF06F,
    0x00000013, 0x00000013, 0x00000013, 0x00000013, 0x00000013,
]

class PyuvmConcurrentTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        self.env.scoreboard.require_events = {
            "program_loaded", "cpu_started"
        }
        self.env.scoreboard.expected_gpio = 0x05
        self.env.scoreboard.expected_uart = 0x41
        self.env.scoreboard.expected_spi = 0xB7

        for i, w in enumerate(PROG):
            item = ScanItem(f"w{i}", tgt=0, addr=i, data=w)
            await self.env.scan_agent.sequencer.start_item(item)
            await self.env.scan_agent.sequencer.finish_item(item)
        cov.sample_event("program_loaded")

        # RUN
        item = ScanItem("run", tgt=1, addr=0, data=0x00010000)
        await self.env.scan_agent.sequencer.start_item(item)
        await self.env.scan_agent.sequencer.finish_item(item)
        cov.sample_event("cpu_started")

        await Timer(25000, unit="ns")

        gpio = int(dut_handle.DUT.gpio_out.value) & 0x1F
        self.logger.info(f"GPIO={gpio:#04x} (expect 0x05)")
        assert gpio == 0x05, f"GPIO mismatch {gpio:#x}"

        self.logger.info("*** concurrent GPIO+UART+SPI PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_concurrent(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmConcurrentTest")
