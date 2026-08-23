from pyuvm import uvm_agent
from .monitor import UartMonitor

class UartAgent(uvm_agent):
    def build_phase(self):
        self.monitor = UartMonitor.create("monitor", self)
