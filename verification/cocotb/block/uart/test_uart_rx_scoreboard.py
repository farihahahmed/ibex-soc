"""MDV RX: bit-bang serial → APB DATA must match uart_rx_pred."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from tb.agents.apb import ApbItem, ApbDriver, dut_handle
from tb.predictors.uart_tx_pred import expected_tx_bits
from tb.predictors.uart_rx_pred import decode_rx_frame

BIT_CYCLES = 8

async def uart_drive_rx(dut, byte):
    dut.rx.value = 1
    for _ in range(BIT_CYCLES):
        await RisingEdge(dut.PCLK)
    # drive full frame from predictor (same model as TX)
    for bit in expected_tx_bits(byte):
        dut.rx.value = bit
        for _ in range(BIT_CYCLES):
            await RisingEdge(dut.PCLK)
    dut.rx.value = 1
    for _ in range(BIT_CYCLES * 2):
        await RisingEdge(dut.PCLK)

@cocotb.test()
async def test_uart_rx_scoreboard(dut):
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
    frame = expected_tx_bits(byte)
    assert decode_rx_frame(frame) == byte  # predictor self-check

    await uart_drive_rx(dut, byte)

    drv = ApbDriver("drv", None)
    # poll STATUS rx_valid (bit1)
    for _ in range(50):
        await drv._do_transfer(ApbItem("st", write=0, addr=0x0, data=0))
        st = int(dut.PRDATA.value)
        if st & 0x2:
            break
        for __ in range(4):
            await RisingEdge(dut.PCLK)
    else:
        assert False, "rx_valid never set"

    await drv._do_transfer(ApbItem("rd", write=0, addr=0x4, data=0))
    got = int(dut.PRDATA.value) & 0xFF
    assert got == byte, f"DATA got 0x{got:02x} expect 0x{byte:02x}"
    cocotb.log.info(f"*** RX SCOREBOARD PASS: 0x{got:02x} ***")
