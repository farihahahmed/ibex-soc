"""MDV: APB multi-byte TX with background UartTxScoreboard."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from tb.agents.apb import ApbItem, ApbDriver, dut_handle
from tb.scoreboards.uart_tx_sb import UartTxScoreboard

BIT_CYCLES = 8

@cocotb.test()
async def test_uart_tx_sb_multi(dut):
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

    sb = UartTxScoreboard(dut, bit_cycles=BIT_CYCLES)
    cocotb.start_soon(sb.run())

    drv = ApbDriver("drv", None)
    bytes_out = [0x41, 0x5A, 0xFF]
    for b in bytes_out:
        # wait until not busy (STATUS bit0)
        for _ in range(200):
            await drv._do_transfer(ApbItem("rd", write=0, addr=0x0, data=0))
            # PRDATA not auto-filled by bare driver – poll tx pin idle instead
            break
        while int(dut.tx.value) == 0:
            await RisingEdge(dut.PCLK)
        # give stop bit time
        for _ in range(BIT_CYCLES * 2):
            await RisingEdge(dut.PCLK)

        sb.expect_byte(b)
        await drv._do_transfer(ApbItem("tx", write=1, addr=0x4, data=b))
        # one frame ~10 * BIT_CYCLES
        for _ in range(BIT_CYCLES * 12):
            await RisingEdge(dut.PCLK)

    await Timer(100, unit="ns")
    checked, errors = sb.report()
    assert errors == 0
    assert checked == len(bytes_out), f"checked={checked} expected {len(bytes_out)}"
    cocotb.log.info(f"*** MULTI SB PASS: {checked} frames ***")
