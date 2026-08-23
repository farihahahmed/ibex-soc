"""Simple SPI MOSI monitor (Mode 0 style)"""

import cocotb
from cocotb.triggers import RisingEdge

class SpiMonitor:
    def __init__(self, dut, name="spi"):
        self.dut = dut
        self.name = name
        self.bytes = []
        self._current = 0
        self._bits = 0

    async def run(self):
        """Capture bytes on rising SCLK"""
        while True:
            await RisingEdge(self.dut.spi_sclk)
            bit = int(self.dut.spi_mosi.value) & 1
            self._current = ((self._current << 1) | bit) & 0xFF
            self._bits += 1

            if self._bits == 8:
                self.bytes.append(self._current)
                cocotb.log.info(f"[{self.name}] MOSI byte 0x{self._current:02x}")
                self._current = 0
                self._bits = 0
