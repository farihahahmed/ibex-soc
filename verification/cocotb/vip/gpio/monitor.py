"""Simple GPIO monitor"""

import cocotb
from cocotb.triggers import Edge

class GpioMonitor:
    def __init__(self, dut, name="gpio"):
        self.dut = dut
        self.name = name
        self.last_value = 0
        self.changes = []

    async def run(self):
        while True:
            await self.dut.gpio_out.value_change
            val = int(self.dut.gpio_out.value) & 0x1F
            if val != self.last_value:
                t = cocotb.utils.get_sim_time(unit="ns")
                self.changes.append((t, val))
                self.last_value = val
                cocotb.log.info(f"[{self.name}] GPIO changed → 0x{val:02x} @ {t} ns")

    def get_final(self):
        return self.last_value
