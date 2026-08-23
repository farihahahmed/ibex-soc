from pyuvm import uvm_agent, uvm_active_passive_enum
from .driver import ScanDriver
from .sequencer import ScanSequencer

class ScanAgent(uvm_agent):
    def build_phase(self):
        super().build_phase()
        if self.get_is_active() == uvm_active_passive_enum.UVM_ACTIVE:
            self.driver = ScanDriver.create("driver", self)
            self.sequencer = ScanSequencer.create("sequencer", self)

    def connect_phase(self):
        if self.get_is_active() == uvm_active_passive_enum.UVM_ACTIVE:
            self.driver.seq_item_port.connect(self.sequencer.seq_item_export)
