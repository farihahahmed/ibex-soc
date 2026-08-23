"""APB signal map — one UVC for block top or chip hierarchy."""

class ApbIf:
    def __init__(self, pclk, presetn, psel, penable, pwrite, paddr, pwdata, prdata, pready):
        self.PCLK = pclk
        self.PRESETn = presetn
        self.PSEL = psel
        self.PENABLE = penable
        self.PWRITE = pwrite
        self.PADDR = paddr
        self.PWDATA = pwdata
        self.PRDATA = prdata
        self.PREADY = pready

    @staticmethod
    def from_block(dut):
        """Block DUT is apb_uart / apb_gpio / apb_spi top."""
        return ApbIf(
            dut.PCLK, dut.PRESETn, dut.PSEL, dut.PENABLE, dut.PWRITE,
            dut.PADDR, dut.PWDATA, dut.PRDATA, dut.PREADY,
        )

    @staticmethod
    def from_chip(dut):
        """Chip: shared APB after bridge (before per-slave decode)."""
        return ApbIf(
            dut.cpu_clk, dut.rst_n, dut.PSEL, dut.PENABLE, dut.PWRITE,
            dut.PADDR, dut.PWDATA, dut.PRDATA, dut.PREADY,
        )
