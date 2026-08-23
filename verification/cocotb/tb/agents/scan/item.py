from pyuvm import uvm_sequence_item

class ScanItem(uvm_sequence_item):
    def __init__(self, name="scan_item", tgt=0, addr=0, data=0):
        super().__init__(name)
        self.tgt = tgt & 0x3
        self.addr = addr & 0x3FFF
        self.data = data & 0xFFFFFFFF

    def __str__(self):
        return f"ScanItem(tgt={self.tgt}, addr=0x{self.addr:04x}, data=0x{self.data:08x})"
