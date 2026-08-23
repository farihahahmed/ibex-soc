"""Block UART: APB write + predictor scoreboard on serial bits."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from tb.agents.apb import ApbItem
from tb.agents.apb import ApbDriver
from tb.agents.apb import dut_handle
from tb.predictors.uart_tx_pred import expected_tx_bits

BIT_CYCLES = 8

@cocotb.test()
async def test_uart_tx_scoreboard(dut):
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

    byte = 0x5A
    expect = expected_tx_bits(byte)
    drv = ApbDriver("drv", None)
    await drv._do_transfer(ApbItem("tx", write=1, addr=0x4, data=byte))

    await FallingEdge(dut.tx)
    # mid of start
    for _ in range(BIT_CYCLES // 2):
        await RisingEdge(dut.PCLK)

    observed = []
    for bi, exp in enumerate(expect):
        got = int(dut.tx.value) & 1
        observed.append(got)
        assert got == exp, f"bit{bi}: got {got} expect {exp} (byte=0x{byte:02x})"
        if bi < len(expect) - 1:
            for _ in range(BIT_CYCLES):
                await RisingEdge(dut.PCLK)

    cocotb.log.info(f"*** SCOREBOARD PASS: bits={observed} ***")
