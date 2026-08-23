"""Block UART: write 0x41, decode full UART frame on tx."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from tb.agents.apb import ApbItem
from tb.agents.apb import ApbDriver
from tb.agents.apb import dut_handle

BIT_CYCLES = 8  # CLK_FREQ=8 / BAUD_RATE=1

@cocotb.test()
async def test_uart_tx_byte(dut):
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
    await drv._do_transfer(ApbItem("tx", write=1, addr=0x4, data=0x41))

    await FallingEdge(dut.tx)                 # start edge
    for _ in range(BIT_CYCLES + BIT_CYCLES // 2):
        await RisingEdge(dut.PCLK)            # mid of bit0
    val = 0
    for i in range(8):
        val |= (int(dut.tx.value) & 1) << i
        if i < 7:
            for _ in range(BIT_CYCLES):
                await RisingEdge(dut.PCLK)
    for _ in range(BIT_CYCLES):               # into stop bit
        await RisingEdge(dut.PCLK)
    assert int(dut.tx.value) == 1, "missing stop bit"
    assert val == 0x41, f"decoded 0x{val:02x}, expected 0x41"
    cocotb.log.info(f"*** UART TX BYTE PASS: decoded 0x{val:02x} ***")
