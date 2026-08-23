"""Constrained-random SPI TX: program writes one random byte to SPI."""
import random
from pyuvm import uvm_sequence
from tb.agents.scan import ScanItem
from tb.coverage import cov

def make_spi_tx_prog(byte: int):
    """RV32I: write `byte` to SPI (0x0003_0000), then spin."""
    b = byte & 0xFF
    return [
        0x00030537,              # lui  a0, 0x30
        0x00000293 | (b << 20),  # addi t0, x0, byte
        0x00552023,              # sw   t0, 0(a0)
        0x00000013,
        0x0000006F,
    ]

class RandomSpiTxSeq(uvm_sequence):
    def __init__(self, name, seed=None):
        super().__init__(name)
        if seed is not None:
            random.seed(seed)
        self.byte = random.randint(1, 255)

    async def body(self):
        prog = make_spi_tx_prog(self.byte)
        for i, w in enumerate(prog):
            item = ScanItem(f"s{i}", tgt=0, addr=i, data=w)
            await self.start_item(item)
            await self.finish_item(item)
        cov.sample_event("program_loaded")

        item = ScanItem("clkgen", tgt=2, addr=0, data=0)
        await self.start_item(item)
        await self.finish_item(item)
        item = ScanItem("run", tgt=1, addr=0, data=0x00010000)
        await self.start_item(item)
        await self.finish_item(item)
        cov.sample_event("cpu_started")
