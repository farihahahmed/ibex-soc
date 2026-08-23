import os, random
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
async def test_gpio_random(dut):
    seed = int(os.environ.get("RANDOM_SEED", "42"))
    random.seed(seed)
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

    for i in range(8):
        val = random.randint(0, 31)  # 5-bit OUT
        await apb_write(dut, val)
        await RisingEdge(dut.PCLK)
        got = int(dut.gpio_out.value)
        cocotb.log.info(f"[{i}] exp=0x{val:02x} got=0x{got:02x}")
        assert got == val
    cocotb.log.info(f"*** GPIO RANDOM PASS seed={seed} ***")
