from pathlib import Path
from pyuvm import uvm_sequence
from tb.agents.scan import ScanItem
from tb.coverage import cov

def load_bin_words(path):
    data = Path(path).read_bytes()
    while len(data) % 4:
        data += b'\x00'
    words = []
    for i in range(0, len(data), 4):
        w = data[i] | (data[i+1] << 8) | (data[i+2] << 16) | (data[i+3] << 24)
        words.append(w)
    return words

class LoadFirmwareSeq(uvm_sequence):
    def __init__(self, name, bin_path):
        super().__init__(name)
        self.bin_path = bin_path

    async def body(self):
        words = load_bin_words(self.bin_path)
        for i, w in enumerate(words):
            item = ScanItem(f"fw_{i}", tgt=0, addr=i, data=w)
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
