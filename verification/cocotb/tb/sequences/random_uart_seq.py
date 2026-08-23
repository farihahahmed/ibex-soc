"""Constrained-random UART TX: load a tiny program that writes one random byte."""
import random
from pyuvm import uvm_sequence
from tb.agents.scan import ScanItem
from tb.coverage import cov

def make_uart_tx_prog(byte: int):
    """RV32I: write `byte` to UART DATA (0x0002_0004), then spin."""
    b = byte & 0xFF
    return [
        0x00020537,              # lui  a0, 0x20        # UART base 0x00020000
        0x00000293 | (b << 20),  # addi t0, x0, byte
        0x00552223,              # sw   t0, 4(a0)       # DATA
        0x00000013,              # nop
        0x0000006F,              # j    .
    ]

class RandomUartTxSeq(uvm_sequence):
    def __init__(self, name, seed=None, n_bytes=3):
        super().__init__(name)
        if seed is not None:
            random.seed(seed)
        self.bytes = [random.randint(0x20, 0x7E) for _ in range(n_bytes)]  # printable

    async def body(self):
        # One program that TXes first byte (simple, reliable); multi-byte can extend later
        b = self.bytes[0]
        prog = make_uart_tx_prog(b)
        for i, w in enumerate(prog):
            item = ScanItem(f"u{i}", tgt=0, addr=i, data=w)
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
