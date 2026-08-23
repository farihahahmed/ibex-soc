"""Simple UART TX monitor (8N1)"""

import cocotb
from cocotb.triggers import RisingEdge, ClockCycles

class UartMonitor:
    def __init__(self, dut, bit_cycles=8, name="uart"):
        self.dut = dut
        self.bit_cycles = bit_cycles
        self.name = name
        self.bytes = []            # list of received bytes

    async def run(self):
        """Continuously capture UART bytes"""
        while True:
            # Wait for start bit (falling edge)
            while int(self.dut.uart_tx.value) == 1:
                await RisingEdge(self.dut.clk)

            # Mid-start-bit
            await ClockCycles(self.dut.clk, self.bit_cycles // 2)

            val = 0
            for b in range(8):
                await ClockCycles(self.dut.clk, self.bit_cycles)
                val |= (int(self.dut.uart_tx.value) & 1) << b

            self.bytes.append(val)
            cocotb.log.info(f"[{self.name}] RX byte 0x{val:02x}")
