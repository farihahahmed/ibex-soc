"""UART RX end-to-end: bit-bang RX → FW reads DATA → GPIO shows byte."""
import os
import random
import cocotb
from cocotb.triggers import Timer, RisingEdge
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.agents.scan import ScanItem
from tb.coverage import cov
from tb import dut_handle
from common import init_dut

# Poll UART STATUS bit1 (rx_valid), read DATA, write to GPIO (0x00010000), spin
# a0 = UART 0x00020000, a1 = GPIO 0x00010000
RX_ECHO_PROG = [
    0x00020537,  # lui  a0, 0x20
    0x000105B7,  # lui  a1, 0x10
    # loop:
    0x00052283,  # lw   t0, 0(a0)       # STATUS
    0x0022F293,  # andi t0, t0, 2       # rx_valid
    0xFE028CE3,  # beq  t0, x0, loop    # -8
    0x00452283,  # lw   t0, 4(a0)       # DATA
    0x0055A023,  # sw   t0, 0(a1)       # GPIO = byte
    0x0000006F,  # j    .
]

async def uart_send_byte(dut, byte, bit_cycles=8):
    dut.uart_rx.value = 0
    for _ in range(bit_cycles):
        await RisingEdge(dut.clk)
    for i in range(8):
        dut.uart_rx.value = (byte >> i) & 1
        for _ in range(bit_cycles):
            await RisingEdge(dut.clk)
    dut.uart_rx.value = 1
    for _ in range(bit_cycles * 2):
        await RisingEdge(dut.clk)

class PyuvmUartRxE2ETest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        seed = int(os.environ.get("RANDOM_SEED", "42"))
        random.seed(seed)
        byte = random.randint(1, 31)  # fits GPIO[4:0]

        for i, w in enumerate(RX_ECHO_PROG):
            item = ScanItem(f"p{i}", tgt=0, addr=i, data=w)
            await self.env.scan_agent.sequencer.start_item(item)
            await self.env.scan_agent.sequencer.finish_item(item)
        cov.sample_event("program_loaded")

        item = ScanItem("clkgen", tgt=2, addr=0, data=0)
        await self.env.scan_agent.sequencer.start_item(item)
        await self.env.scan_agent.sequencer.finish_item(item)
        item = ScanItem("run", tgt=1, addr=0, data=0x00010000)
        await self.env.scan_agent.sequencer.start_item(item)
        await self.env.scan_agent.sequencer.finish_item(item)
        cov.sample_event("cpu_started")

        dut = dut_handle.DUT
        self.env.scoreboard.expected_gpio = byte
        self.env.scoreboard.require_events = {
            "program_loaded", "cpu_started", "gpio_matched"
        }

        dut.uart_rx.value = 1
        await Timer(1000, unit="ns")
        await uart_send_byte(dut, byte)

        # Wait for FW poll + GPIO write
        matched = False
        for _ in range(20000):
            await RisingEdge(dut.clk)
            try:
                g = int(dut.gpio_out.value) & 0x1F
            except Exception:
                g = -1
            if g == byte:
                matched = True
                break

        self.logger.info(
            f"seed={seed} RX byte=0x{byte:02x} GPIO=0x{int(dut.gpio_out.value)&0x1F:02x} matched={matched}"
        )
        assert matched, f"GPIO never showed RX byte 0x{byte:02x}"
        cov.sample_event("uart_matched")
        cov.sample_event("gpio_matched")
        self.logger.info("*** UART RX E2E PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_uart_rx_e2e(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    from tb.coverage.fsm_cov import sample_fsms, fsm_cov
    cocotb.start_soon(sample_fsms(dut, dut.clk))
    await uvm_root().run_test("PyuvmUartRxE2ETest")
    dut._log.info(fsm_cov.report())
    fsm_cov.persist()
