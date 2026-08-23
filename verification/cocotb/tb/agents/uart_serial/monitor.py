"""Passive UART TX monitor — 8N1, LSB first. BIT_CYCLES matches BAUD_RATE=1, CLK_FREQ=8 → 8 cycles/bit."""
from cocotb.triggers import FallingEdge, Timer
from pyuvm import uvm_component, uvm_analysis_port
from tb.agents.apb import dut_handle

BIT_CYCLES = 8  # CLK_FREQ/BAUD_RATE for block TB


class UartTxByte:
    def __init__(self, data):
        self.data = data & 0xFF

    def __str__(self):
        return f"UART_TX 0x{self.data:02x} '{chr(self.data) if 32 <= self.data < 127 else '?'}'"


class UartSerialTxMonitor(uvm_component):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        dut = dut_handle.DUT
        while True:
            await FallingEdge(dut.tx)  # start bit
            # mid of start bit
            await Timer(BIT_CYCLES // 2 * 10, unit="ns")  # PCLK=10ns period
            byte = 0
            for i in range(8):
                await Timer(BIT_CYCLES * 10, unit="ns")
                bit = int(dut.tx.value) & 1
                byte |= bit << i
            await Timer(BIT_CYCLES * 10, unit="ns")  # stop bit
            item = UartTxByte(byte)
            self.logger.info(f"[UART TX mon] {item}")
            self.ap.write(item)
