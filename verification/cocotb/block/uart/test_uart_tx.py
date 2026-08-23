"""Block UART: APB write DATA -> observe start bit on tx."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from tb.agents.apb import ApbItem
from tb.agents.apb import ApbDriver
from tb.agents.apb import dut_handle

@cocotb.test()
async def test_uart_tx(dut):
    dut_handle.DUT = dut
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.rx.value = 1
    for _ in range(4):
        await RisingEdge(dut.PCLK)
    dut.PRESETn.value = 1
    for _ in range(2):
        await RisingEdge(dut.PCLK)

    drv = ApbDriver("drv", None)
    item = ApbItem("tx", write=1, addr=0x4, data=0x41)
    await drv._do_transfer(item)

    for _ in range(50):
        await RisingEdge(dut.PCLK)
        if int(dut.tx.value) == 0:
            cocotb.log.info("*** UART TX PASS: saw start bit after write 0x41 ***")
            return
    assert False, "tx never went low after DATA write"
