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

async def apb_read(dut):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await RisingEdge(dut.PCLK)
    val = int(dut.PRDATA.value)
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    return val

@cocotb.test()
async def test_gpio_inout(dut):
    """Drive gpio_in, read back after 2-FF sync; also write OUT."""
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

    await apb_write(dut, 0x0A)
    await RisingEdge(dut.PCLK)
    assert int(dut.gpio_out.value) == 0x0A

    dut.gpio_in.value = 0x3  # both input pins high
    for _ in range(4):
        await RisingEdge(dut.PCLK)
    r = await apb_read(dut)
    cocotb.log.info(f"gpio_in sync read = 0x{r:02x}")
    assert (r & 0x3) == 0x3
    cocotb.log.info("*** GPIO INOUT PASS ***")
