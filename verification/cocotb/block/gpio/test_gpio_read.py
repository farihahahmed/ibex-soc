"""GPIO MDV read: gpio_in → 2-flop sync → APB PRDATA."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

async def apb_read(dut):
    await RisingEdge(dut.PCLK)
    dut.PADDR.value = 0
    dut.PWRITE.value = 0
    dut.PSEL.value = 1
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await RisingEdge(dut.PCLK)
    val = int(dut.PRDATA.value)
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    return val

@cocotb.test()
async def test_gpio_read(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.gpio_in.value = 0

    dut.PRESETn.value = 0
    for _ in range(5):
        await RisingEdge(dut.PCLK)
    dut.PRESETn.value = 1
    for _ in range(3):
        await RisingEdge(dut.PCLK)

    for pin in [0x1, 0x2, 0x3, 0x0]:
        dut.gpio_in.value = pin
        # 2-flop sync needs a few clocks
        for _ in range(4):
            await RisingEdge(dut.PCLK)
        got = await apb_read(dut)
        cocotb.log.info(f"[SB] PRDATA=0x{got:02x} expect in=0x{pin:02x}")
        assert (got & 0x3) == pin
    cocotb.log.info("*** MDV GPIO read PASS ***")
