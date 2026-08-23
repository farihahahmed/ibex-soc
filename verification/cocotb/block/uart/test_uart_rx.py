"""Block UART: bit-bang one byte on rx, read via APB DATA."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from tb.agents.apb import ApbItem
from tb.agents.apb import ApbDriver
from tb.agents.apb import dut_handle

BIT_CYCLES = 8

async def uart_drive_rx(dut, byte):
    # idle high
    dut.rx.value = 1
    for _ in range(BIT_CYCLES):
        await RisingEdge(dut.PCLK)
    # start
    dut.rx.value = 0
    for _ in range(BIT_CYCLES):
        await RisingEdge(dut.PCLK)
    # 8 data LSB first
    for i in range(8):
        dut.rx.value = (byte >> i) & 1
        for _ in range(BIT_CYCLES):
            await RisingEdge(dut.PCLK)
    # stop
    dut.rx.value = 1
    for _ in range(BIT_CYCLES * 2):
        await RisingEdge(dut.PCLK)

@cocotb.test()
async def test_uart_rx(dut):
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

    byte = 0xA5
    await uart_drive_rx(dut, byte)

    drv = ApbDriver("drv", None)
    # STATUS @ 0: bit1 = rx_valid
    st = ApbItem("st", write=0, addr=0x0, data=0)
    await drv._do_transfer(st)
    assert (st.rdata & 2) != 0, f"rx_valid not set, STATUS=0x{st.rdata:x}"

    data = ApbItem("rd", write=0, addr=0x4, data=0)
    await drv._do_transfer(data)
    assert data.rdata & 0xFF == byte, f"got 0x{data.rdata & 0xFF:02x} expected 0x{byte:02x}"
    cocotb.log.info(f"*** UART RX PASS: read 0x{byte:02x} ***")
