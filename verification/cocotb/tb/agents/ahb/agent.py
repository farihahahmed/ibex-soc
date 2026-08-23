"""AHB-Lite master agent."""
from pyuvm import uvm_agent, uvm_sequencer
from .driver import AhbDriver
from .monitor import AhbMonitor

class AhbAgent(uvm_agent):
    def build_phase(self):
        self.sequencer = uvm_sequencer("sequencer", self)
        self.driver = AhbDriver("driver", self)
        self.monitor = AhbMonitor("monitor", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.sequencer.seq_item_export)
