from pyuvm import uvm_agent
from .monitor import SpiMonitor

class SpiAgent(uvm_agent):
    def build_phase(self):
        self.monitor = SpiMonitor.create("monitor", self)
