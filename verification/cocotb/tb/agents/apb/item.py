"""APB transaction for block-level UART MDV."""
from pyuvm import uvm_sequence_item


class ApbItem(uvm_sequence_item):
    def __init__(self, name="apb", write=False, addr=0, data=0):
        super().__init__(name)
        self.write = bool(write)
        self.addr = int(addr) & 0xFFFFFFFF
        self.data = int(data) & 0xFFFFFFFF
        self.rdata = 0  # filled by driver on reads

    def __str__(self):
        if self.write:
            return f"APB WR addr=0x{self.addr:08x} data=0x{self.data:08x}"
        return f"APB RD addr=0x{self.addr:08x} -> 0x{self.rdata:08x}"
