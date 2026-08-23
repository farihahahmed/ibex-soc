"""APB protocol checks (B3)."""
import cocotb

class ApbProtocolChecker:
    def __init__(self):
        self.log = cocotb.log
        self.errors = 0

    def check_access(self, psel, penable, pready):
        if int(penable) and not int(psel):
            self.log.error("APB: PENABLE=1 while PSEL=0")
            self.errors += 1

    def report(self):
        if self.errors:
            raise AssertionError(f"APB protocol errors: {self.errors}")
        self.log.info("APB protocol checker: OK")
