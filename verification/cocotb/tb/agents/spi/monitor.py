from cocotb.triggers import RisingEdge
from pyuvm import uvm_component, uvm_analysis_port
from tb import dut_handle
from .item import SpiItem

class SpiMonitor(uvm_component):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        dut = dut_handle.DUT
        while True:
            byte = 0
            for i in range(8):
                await RisingEdge(dut.spi_sclk)
                bit = int(dut.spi_mosi.value) & 1
                byte = ((byte << 1) | bit) & 0xFF
            item = SpiItem(data=byte)
            self.logger.info(f"[SPI mon] {item}")
            self.ap.write(item)
