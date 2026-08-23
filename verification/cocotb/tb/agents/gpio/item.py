from pyuvm import uvm_sequence_item

class GpioItem(uvm_sequence_item):
    def __init__(self, name="gpio_item", value=0):
        super().__init__(name)
        self.value = value & 0x1F

    def __str__(self):
        return f"GpioItem(value=0x{self.value:02x})"
