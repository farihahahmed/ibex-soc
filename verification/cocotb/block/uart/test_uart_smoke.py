"""Block UART smoke — shared ApbAgent + TX idle."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from pyuvm import uvm_test, uvm_root, uvm_sequencer, uvm_sequence, ConfigDB
from tb.agents.apb import ApbAgent, ApbItem, ApbIf, dut_handle


class TxWriteSeq(uvm_sequence):
    async def body(self):
        item = ApbItem("tx", write=True, addr=0x4, data=0x41)
        await self.start_item(item)
        await self.finish_item(item)


class UartSmokeTest(uvm_test):
    def build_phase(self):
        self.agent = ApbAgent("apb_agent", self)

    async def run_phase(self):
        self.raise_objection()
        seq = TxWriteSeq("tx")
        await seq.start(self.agent.seqr)
        await Timer(500, unit="ns")
        self.drop_objection()


@cocotb.test()
async def test_uart_smoke(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.rx.value = 1

    await Timer(50, unit="ns")
    dut.PRESETn.value = 1
    for _ in range(5):
        await RisingEdge(dut.PCLK)

    # Shared bus UVC map (block ports)
    dut_handle.IF = ApbIf.from_block(dut)
    dut_handle.DUT = dut  # legacy fallback

    assert int(dut.tx.value) == 1, "TX should idle high before write"
    await uvm_root().run_test("UartSmokeTest")
    cocotb.log.info("*** UART block smoke PASS (shared ApbAgent write 0x41) ***")
