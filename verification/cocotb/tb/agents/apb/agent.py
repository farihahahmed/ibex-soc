"""APB master agent: sequencer + driver + monitor."""
from pyuvm import uvm_agent, uvm_sequencer
from tb.agents.apb.driver import ApbDriver
from tb.agents.apb.monitor import ApbMonitor


class ApbAgent(uvm_agent):
    def build_phase(self):
        self.seqr = uvm_sequencer("seqr", self)
        self.driver = ApbDriver("driver", self)
        self.monitor = ApbMonitor("monitor", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)
