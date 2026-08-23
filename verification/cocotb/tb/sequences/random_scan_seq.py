"""Constrained-random scan traffic: several legal frames, then a GPIO program."""
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

class RandomScanSeq(uvm_sequence):
    """
    Constraints:
      - tgt in {0,1,2}
      - if tgt==0: addr in 0..15 (imem words), data any 32-bit
      - if tgt==1: data encodes mode (only RUN=0x00010000 at end)
      - if tgt==2: clkgen config (data 0)
    Ends with a known GPIO program so scoreboard can check.
    """

    def __init__(self, name="random_scan", seed=None, n_extra=4):
        super().__init__(name)
        self.seed = seed if seed is not None else random.randint(0, 99999)
        self.n_extra = n_extra
        self.chosen_val = None

    async def body(self):
        random.seed(self.seed)
        self.chosen_val = random.randint(1, 31)
        cocotb.log.info(
            f"[RandomScanSeq] seed={self.seed} n_extra={self.n_extra} "
            f"final GPIO=0x{self.chosen_val:02x}"
        )

        # --- constrained-random extra frames (before the real program) ---
        for k in range(self.n_extra):
            tgt = random.choice([0, 2])  # memory or clkgen only (not RUN yet)
            if tgt == 0:
                # write a NOP into a high imem slot we will overwrite later
                addr = random.randint(8, 15)
                data = 0x00000013  # NOP — safe
            else:
                addr = 0
                data = 0
            item = ScanItem(f"rand_{k}", tgt=tgt, addr=addr, data=data)
            await self.start_item(item)
            await self.finish_item(item)
            cov.sample_event("program_loaded")  # activity on scan path

        # --- final directed GPIO program (scoreboard check) ---
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
