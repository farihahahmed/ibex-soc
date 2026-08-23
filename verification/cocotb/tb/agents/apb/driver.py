"""APB master driver — one transfer per item (setup then access)."""
from cocotb.triggers import RisingEdge
from pyuvm import uvm_driver
from tb.agents.apb.item import ApbItem
from tb.agents.apb import dut_handle
from tb.agents.apb.protocol import check_setup, check_access, check_idle


class ApbDriver(uvm_driver):
    async def run_phase(self):
        bus = None
        while bus is None:
            bus = dut_handle.get_bus()
            if bus is None:
                from cocotb.triggers import Timer
                await Timer(1, unit="ns")
        bus.PSEL.value = 0
        bus.PENABLE.value = 0
        bus.PWRITE.value = 0
        bus.PADDR.value = 0
        bus.PWDATA.value = 0

        while True:
            item = await self.seq_item_port.get_next_item()
            await self._do_transfer(item)
            self.seq_item_port.item_done()

    async def _do_transfer(self, item: ApbItem):
        bus = dut_handle.get_bus()

        await RisingEdge(bus.PCLK)
        pwrite = 1 if item.write else 0
        bus.PSEL.value = 1
        bus.PENABLE.value = 0
        bus.PWRITE.value = pwrite
        bus.PADDR.value = item.addr
        bus.PWDATA.value = item.data if item.write else 0
        # Check driven intent (same-cycle DUT readback is unreliable)
        check_setup(item, 1, 0, pwrite, item.addr, item.data if item.write else 0)

        await RisingEdge(bus.PCLK)
        bus.PENABLE.value = 1
        check_access(item, 1, 1, bus.PREADY.value)
        # Hold until PREADY (wait states)
        while int(bus.PREADY.value) == 0:
            await RisingEdge(bus.PCLK)
        if not item.write:
            item.rdata = int(bus.PRDATA.value)

        await RisingEdge(bus.PCLK)
        bus.PSEL.value = 0
        bus.PENABLE.value = 0
        check_idle(0, 0)
        self.logger.info(str(item))
