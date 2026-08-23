"""UART TX scoreboard: APB DATA writes → expected serial bits vs observed."""
from collections import deque
from cocotb.triggers import FallingEdge, RisingEdge
from tb.predictors.uart_tx_pred import expected_tx_bits


class UartTxScoreboard:
    def __init__(self, dut, bit_cycles=8):
        self.dut = dut
        self.bit_cycles = bit_cycles
        self.pending = deque()  # expected bit lists
        self.errors = 0
        self.checked = 0

    def expect_byte(self, byte: int):
        self.pending.append(expected_tx_bits(byte & 0xFF))

    async def run(self):
        """Background: on each start bit, score one pending frame."""
        while True:
            await FallingEdge(self.dut.tx)
            if not self.pending:
                continue
            expect = self.pending.popleft()
            # sample mid-start
            for _ in range(self.bit_cycles // 2):
                await RisingEdge(self.dut.PCLK)
            for bi, exp in enumerate(expect):
                got = int(self.dut.tx.value) & 1
                if got != exp:
                    self.errors += 1
                    raise AssertionError(
                        f"TX bit{bi}: got {got} expect {exp}"
                    )
                if bi < len(expect) - 1:
                    for _ in range(self.bit_cycles):
                        await RisingEdge(self.dut.PCLK)
            self.checked += 1

    def report(self):
        return self.checked, self.errors
