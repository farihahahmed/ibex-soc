from pyuvm import uvm_sequence_item

class UartItem(uvm_sequence_item):
    def __init__(self, name="uart_item", data=0):
        super().__init__(name)
        self.data = data & 0xFF

    def __str__(self):
        ch = chr(self.data) if 32 <= self.data < 127 else "."
        return f"UartItem(data=0x{self.data:02x} '{ch}')"
