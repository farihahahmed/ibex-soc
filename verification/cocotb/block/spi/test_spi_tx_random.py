"""Block SPI random TX: random byte via APB, check MOSI."""
import os
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def apb_write(dut, data):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1
    dut.PWRITE.value = 1
    dut.PADDR.value = 0
    dut.PWDATA.value = data & 0xFF
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0

@cocotb.test()
async def test_spi_tx_random(dut):
    seed = int(os.environ.get("RANDOM_SEED", "42"))
    random.seed(seed)
    tx_byte = random.randint(0, 255)

    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.miso.value = 0

    for _ in range(5):
        await RisingEdge(dut.PCLK)
    dut.PRESETn.value = 1
    for _ in range(3):
        await RisingEdge(dut.PCLK)

    cocotb.log.info(f"seed={seed} TX=0x{tx_byte:02x}")
    await apb_write(dut, tx_byte)

    bits = []
    for _ in range(8):
        await RisingEdge(dut.sclk)
        bits.append(int(dut.mosi.value))
    got = 0
    for b in bits:
        got = (got << 1) | b

    assert got == tx_byte, f"seed {seed}: expected 0x{tx_byte:02x}, got 0x{got:02x}"
    await Timer(200, unit="ns")
    cocotb.log.info(f"*** SPI random TX PASS seed={seed} ***")
