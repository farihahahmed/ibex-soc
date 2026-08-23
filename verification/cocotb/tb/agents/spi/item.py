from pyuvm import uvm_sequence_item

class SpiItem(uvm_sequence_item):
    def __init__(self, name="spi_item", data=0):
        super().__init__(name)
        self.data = data & 0xFF

    def __str__(self):
        return f"SpiItem(data=0x{self.data:02x})"
