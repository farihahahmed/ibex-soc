import cocotb
from pyuvm import uvm_component, uvm_analysis_port
from tb import dut_handle
from .item import GpioItem

class GpioMonitor(uvm_component):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        from cocotb.triggers import Timer
        from tb import dut_handle
        dut = dut_handle.DUT
        while dut is None:
            await Timer(1, unit="ns")
            dut = dut_handle.DUT
        dut = dut_handle.DUT
        last = int(dut.gpio_out.value) & 0x1F
        while True:
            await dut.gpio_out.value_change
            val = int(dut.gpio_out.value) & 0x1F
            if val != last:
                item = GpioItem(value=val)
                self.logger.info(f"[GPIO mon] {item}")
                self.ap.write(item)
                last = val
