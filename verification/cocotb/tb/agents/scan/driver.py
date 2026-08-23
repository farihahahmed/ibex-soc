from cocotb.triggers import FallingEdge, RisingEdge
from pyuvm import uvm_driver
from tb import dut_handle

class ScanDriver(uvm_driver):
    async def run_phase(self):
        while True:
            item = await self.seq_item_port.get_next_item()
            await self.drive_item(item)
            self.seq_item_port.item_done()

    async def drive_item(self, item):
        dut = dut_handle.DUT
        frame = (item.tgt << 46) | (item.addr << 32) | item.data
        for i in range(48):
            await FallingEdge(dut.clk)
            dut.scan_in.value = (frame >> i) & 1
            dut.scan_shift.value = 1
        await FallingEdge(dut.clk)
        dut.scan_shift.value = 0
        dut.scan_in.value = 0
        await FallingEdge(dut.clk)
        dut.scan_load.value = 1
        await FallingEdge(dut.clk)
        dut.scan_load.value = 0
        await RisingEdge(dut.clk)
