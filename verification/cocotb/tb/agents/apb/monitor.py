"""APB monitor — ACCESS sample + basic protocol checks."""
from cocotb.triggers import RisingEdge, Timer
from pyuvm import uvm_monitor, uvm_analysis_port
from tb.agents.apb.item import ApbItem
from tb.agents.apb import dut_handle


class ApbMonitor(uvm_monitor):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.errors = 0
        self.xfers = 0

    async def run_phase(self):
        bus = None
        while bus is None:
            bus = dut_handle.get_bus()
            if bus is None:
                await Timer(1, unit="ns")

        prev_psel = 0
        prev_penable = 0

        while True:
            await RisingEdge(bus.PCLK)
            try:
                psel = int(bus.PSEL.value)
                penable = int(bus.PENABLE.value)
                pwrite = int(bus.PWRITE.value)
            except Exception:
                continue

            if penable and not psel:
                self.errors += 1
                self.logger.error("APB PROTO: PENABLE=1 with PSEL=0")

            if psel and penable:
                if not (prev_psel and not prev_penable):
                    self.logger.warning("APB PROTO: ACCESS without prior SETUP")

                item = ApbItem(
                    "mon",
                    write=bool(pwrite),
                    addr=int(bus.PADDR.value),
                    data=int(bus.PWDATA.value) if pwrite else 0,
                )
                if not item.write:
                    item.rdata = int(bus.PRDATA.value)
                self.xfers += 1
                self.logger.info(f"[APB mon] {item}")
                self.ap.write(item)

            prev_psel = psel
            prev_penable = penable
