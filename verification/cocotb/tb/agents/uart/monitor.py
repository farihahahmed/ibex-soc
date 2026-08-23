from cocotb.triggers import RisingEdge, ClockCycles
from pyuvm import uvm_component, uvm_analysis_port
from tb import dut_handle
from .item import UartItem

class UartMonitor(uvm_component):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.bit_cycles = 8

    async def run_phase(self):
        dut = dut_handle.DUT
        while True:
            while int(dut.uart_tx.value) == 1:
                await RisingEdge(dut.clk)
            await ClockCycles(dut.clk, self.bit_cycles // 2)
            val = 0
            for b in range(8):
                await ClockCycles(dut.clk, self.bit_cycles)
                val |= (int(dut.uart_tx.value) & 1) << b
            item = UartItem(data=val)
            self.logger.info(f"[UART mon] {item}")
            self.ap.write(item)
