import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def apb_write(dut, data):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1
    dut.PWRITE.value = 1
    dut.PADDR.value = 0
    dut.PWDATA.value = data
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0
    dut.PENABLE.value = 0

@cocotb.test()
async def test_gpio_out(dut):
    """Write 0x15 → gpio_out must become 0x15."""
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.gpio_in.value = 0
    await Timer(50, unit="ns")
    dut.PRESETn.value = 1
    for _ in range(5):
        await RisingEdge(dut.PCLK)

    await apb_write(dut, 0x15)
    await RisingEdge(dut.PCLK)
    out = int(dut.gpio_out.value)
    cocotb.log.info(f"gpio_out = 0x{out:02x}")
    assert out == 0x15
    cocotb.log.info("*** GPIO OUT PASS ***")
