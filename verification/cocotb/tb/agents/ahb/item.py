"""AHB-Lite transfer item (master side)."""
from pyuvm import uvm_sequence_item

class AhbItem(uvm_sequence_item):
    def __init__(self, name="ahb", write=0, addr=0, data=0, rdata=0):
        super().__init__(name)
        self.write = int(write)   # 1=write, 0=read
        self.addr  = int(addr)
        self.data  = int(data)    # HWDATA for writes
        self.rdata = int(rdata)   # captured HRDATA for reads

    def __str__(self):
        op = "WR" if self.write else "RD"
        return f"AhbItem({op} addr=0x{self.addr:08x} data=0x{self.data:08x} rdata=0x{self.rdata:08x})"
