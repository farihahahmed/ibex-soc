from pyuvm import uvm_sequence
from tb.agents.scan import ScanItem
from tb.coverage import cov

class LoadProgramSeq(uvm_sequence):
    def __init__(self, name, words):
        super().__init__(name)
        self.words = words

    async def body(self):
        for i, w in enumerate(self.words):
            item = ScanItem(f"word_{i}", tgt=0, addr=i, data=w)
            await self.start_item(item)
            await self.finish_item(item)
        cov.sample_event("program_loaded")

class StartCpuSeq(uvm_sequence):
    async def body(self):
        item = ScanItem("clkgen", tgt=2, addr=0, data=0)
        await self.start_item(item)
        await self.finish_item(item)
        item = ScanItem("run", tgt=1, addr=0, data=0x00010000)
        await self.start_item(item)
        await self.finish_item(item)
        cov.sample_event("cpu_started")
