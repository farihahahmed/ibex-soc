from pyuvm import uvm_agent
from .monitor import GpioMonitor

class GpioAgent(uvm_agent):
    def build_phase(self):
        self.monitor = GpioMonitor.create("monitor", self)
