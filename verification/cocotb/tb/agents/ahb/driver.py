"""AHB-Lite master driver (address phase → data phase, wait HREADY)."""
import cocotb
from cocotb.triggers import RisingEdge
from pyuvm import uvm_driver, ConfigDB
from .item import AhbItem

class AhbDriver(uvm_driver):
    def build_phase(self):
        self.dut = ConfigDB().get(self, "", "DUT")

    async def run_phase(self):
        # Idle bus
        self.dut.HTRANS.value = 0   # IDLE
        self.dut.HWRITE.value = 0
        self.dut.HADDR.value  = 0
        self.dut.HWDATA.value = 0
        while True:
            item = await self.seq_item_port.get_next_item()
            await self._xfer(item)
            self.seq_item_port.item_done()

    async def _xfer(self, item: AhbItem):
        # Address phase
        await RisingEdge(self.dut.HCLK)
        self.dut.HADDR.value  = item.addr
        self.dut.HTRANS.value = 0b10  # NONSEQ
        self.dut.HWRITE.value = item.write
        # Data phase next cycle (pipelined)
        await RisingEdge(self.dut.HCLK)
        self.dut.HTRANS.value = 0  # back to IDLE for single xfer
        if item.write:
            self.dut.HWDATA.value = item.data
        # Wait HREADY
        while int(self.dut.HREADY.value) == 0:
            await RisingEdge(self.dut.HCLK)
        if not item.write:
            item.rdata = int(self.dut.HRDATA.value)
        await RisingEdge(self.dut.HCLK)
