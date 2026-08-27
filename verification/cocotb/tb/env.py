from pyuvm import uvm_env
from tb.agents.scan import ScanAgent
from tb.agents.gpio import GpioAgent
from tb.agents.uart import UartAgent
from tb.agents.spi import SpiAgent
from tb.agents.apb import ApbMonitor
from tb.scoreboard import Scoreboard


class PicoSocEnv(uvm_env):
    def build_phase(self):
        self.scan_agent = ScanAgent.create("scan_agent", self)
        self.gpio_agent = GpioAgent.create("gpio_agent", self)
        self.uart_agent = UartAgent.create("uart_agent", self)
        self.spi_agent = SpiAgent.create("spi_agent", self)
        # Shared bus UVC (passive on chip — CPU is APB master)
        self.apb_monitor = ApbMonitor("apb_monitor", self)
        self.scoreboard = Scoreboard.create("scoreboard", self)

    def connect_phase(self):
        self.gpio_agent.monitor.ap.connect(self.scoreboard.gpio_export)
        self.uart_agent.monitor.ap.connect(self.scoreboard.uart_export)
        self.spi_agent.monitor.ap.connect(self.scoreboard.spi_export)
