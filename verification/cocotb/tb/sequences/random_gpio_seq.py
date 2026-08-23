import random
import cocotb
from pyuvm import uvm_sequence
from tb.agents.scan import ScanItem
from tb.coverage import cov

def make_gpio_program(val):
    imm = val & 0x1F
    return [
        0x00010537,
        0x00000093 | ((imm & 0xFFF) << 20),
        0x00152023,
        0x00000013,
        0xFFDFF06F,
    ]

class RandomGpioSeq(uvm_sequence):
    def __init__(self, name="random_gpio", seed=None):
        super().__init__(name)
        self.seed = seed if seed is not None else random.randint(0, 99999)
        self.chosen_val = None

    async def body(self):
        random.seed(self.seed)
        self.chosen_val = random.randint(1, 31)
        cocotb.log.info(f"[RandomGpioSeq] seed={self.seed}  target GPIO=0x{self.chosen_val:02x}")

        prog = make_gpio_program(self.chosen_val)
        for i, w in enumerate(prog):
            item = ScanItem(f"w{i}", tgt=0, addr=i, data=w)
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
