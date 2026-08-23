from pyuvm import uvm_component, uvm_analysis_export
from tb.coverage import cov

class Scoreboard(uvm_component):
    def build_phase(self):
        self.gpio_export = uvm_analysis_export("gpio_export", self)
        self.uart_export = uvm_analysis_export("uart_export", self)
        self.spi_export  = uvm_analysis_export("spi_export", self)
        self.expected_gpio = None
        self.expected_uart = None
        self.expected_spi  = None
        self.seen_gpio = []
        self.seen_uart = []
        self.seen_spi  = []
        self.errors = 0
        # Which coverage events this test cares about
        self.require_events = set()

    def write_gpio(self, item):
        self.seen_gpio.append(item.value)
        cov.sample_gpio(item.value)
        self.logger.info(f"[SB] GPIO observed 0x{item.value:02x}")
        if self.expected_gpio is not None and item.value == self.expected_gpio:
            self.logger.info("[SB] GPIO MATCH")
            cov.sample_event("gpio_matched")

    def write_uart(self, item):
        self.seen_uart.append(item.data)
        self.logger.info(f"[SB] UART observed 0x{item.data:02x}")
        if self.expected_uart is not None and item.data == self.expected_uart:
            self.logger.info("[SB] UART MATCH")
            cov.sample_event("uart_matched")

    def write_spi(self, item):
        self.seen_spi.append(item.data)
        if len(self.seen_spi) == 1:
            cov.sample_event("spi_activity")
        self.logger.info(f"[SB] SPI observed 0x{item.data:02x}")
        if self.expected_spi is not None and item.data == self.expected_spi:
            self.logger.info("[SB] SPI MATCH")

    def connect_phase(self):
        self.gpio_export.write = self.write_gpio
        self.uart_export.write = self.write_uart
        self.spi_export.write  = self.write_spi

    def check_phase(self):
        if self.expected_gpio is not None and self.expected_gpio not in self.seen_gpio:
            self.logger.error(f"[SB] GPIO 0x{self.expected_gpio:02x} never seen")
            self.errors += 1
        if self.expected_uart is not None and self.expected_uart not in self.seen_uart:
            self.logger.error(f"[SB] UART 0x{self.expected_uart:02x} never seen")
            self.errors += 1
        if self.expected_spi is not None and self.expected_spi not in self.seen_spi:
            self.logger.error(f"[SB] SPI 0x{self.expected_spi:02x} never seen")
            self.errors += 1
        if self.errors:
            raise AssertionError(f"Scoreboard: {self.errors} error(s)")
        self.logger.info("[SB] check_phase PASS")
        self.logger.info(cov.report())

        # Enforce only the events this test required
        if self.require_events:
            missing = [e for e in self.require_events if cov.events.hits[e] < 1]
            if missing:
                raise AssertionError(f"Required coverage events missing: {missing}")
