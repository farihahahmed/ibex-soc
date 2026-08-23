"""AHB-Lite monitor – emit AhbItem on completed transfers."""
import cocotb
from cocotb.triggers import RisingEdge
from pyuvm import uvm_monitor, uvm_analysis_port, ConfigDB
from .item import AhbItem

class AhbMonitor(uvm_monitor):
    def build_phase(self):
        self.dut = ConfigDB().get(self, "", "DUT")
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        while True:
            await RisingEdge(self.dut.HCLK)
            # Address phase: real transfer when HTRANS[1]
            if int(self.dut.HTRANS.value) & 0b10:
                addr  = int(self.dut.HADDR.value)
                write = int(self.dut.HWRITE.value)
                # Data phase next cycle
                await RisingEdge(self.dut.HCLK)
                while int(self.dut.HREADY.value) == 0:
                    await RisingEdge(self.dut.HCLK)
                data  = int(self.dut.HWDATA.value) if write else 0
                rdata = 0 if write else int(self.dut.HRDATA.value)
                item = AhbItem("mon", write=write, addr=addr, data=data, rdata=rdata)
                self.logger.info(f"[AHB mon] {item}")
                self.ap.write(item)
