"""Block UART: constrained-random TX bytes, full frame decode."""
import os
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from tb.agents.apb import ApbItem
from tb.agents.apb import ApbDriver
from tb.agents.apb import dut_handle

BIT_CYCLES = 8

async def reset_dut(dut):
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

async def decode_tx_byte(dut):
    await FallingEdge(dut.tx)
    for _ in range(BIT_CYCLES + BIT_CYCLES // 2):
        await RisingEdge(dut.PCLK)
    val = 0
    for i in range(8):
        val |= (int(dut.tx.value) & 1) << i
        if i < 7:
            for _ in range(BIT_CYCLES):
                await RisingEdge(dut.PCLK)
    for _ in range(BIT_CYCLES):
        await RisingEdge(dut.PCLK)
    assert int(dut.tx.value) == 1, "missing stop bit"
    return val

@cocotb.test()
async def test_uart_tx_random(dut):
    seed = int(os.environ.get("RANDOM_SEED", "42"))
    random.seed(seed)
    dut_handle.DUT = dut
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    await reset_dut(dut)
    drv = ApbDriver("drv", None)

    n = 8
    for k in range(n):
        byte = random.randint(0, 255)
        await drv._do_transfer(ApbItem(f"tx{k}", write=1, addr=0x4, data=byte))
        got = await decode_tx_byte(dut)
        assert got == byte, f"seed={seed} i={k}: expected 0x{byte:02x} got 0x{got:02x}"
        cocotb.log.info(f"[{k}] TX 0x{byte:02x} OK")
        # wait for tx_busy clear (idle high a bit)
        for _ in range(BIT_CYCLES * 2):
            await RisingEdge(dut.PCLK)

    cocotb.log.info(f"*** UART TX RANDOM PASS: {n} bytes seed={seed} ***")
