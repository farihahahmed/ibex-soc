"""GPIO block test through the register model (tb.reg_model.soc_regs).

Proves the asymmetric read/write layout the RAL models: writes drive
out[NUM_OUT-1:0]; reads present inputs at [NUM_IN-1:0] and the output
readback above them. Block DUT: apb_gpio with NUM_OUT=4, NUM_IN=2.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tb.reg_model.soc_regs import make_gpio

gpio = make_gpio(num_out=4, num_in=2)   # block-level params


async def reset(dut):
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


async def apb_write(dut, addr, data):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1; dut.PWRITE.value = 1
    dut.PADDR.value = addr; dut.PWDATA.value = data
    dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    while int(dut.PREADY.value) == 0:
        await RisingEdge(dut.PCLK)
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0; dut.PENABLE.value = 0; dut.PWRITE.value = 0


async def apb_read(dut, addr):
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 1; dut.PWRITE.value = 0
    dut.PADDR.value = addr; dut.PENABLE.value = 0
    await RisingEdge(dut.PCLK)
    dut.PENABLE.value = 1
    while int(dut.PREADY.value) == 0:
        await RisingEdge(dut.PCLK)
    val = int(dut.PRDATA.value)
    await RisingEdge(dut.PCLK)
    dut.PSEL.value = 0; dut.PENABLE.value = 0
    return val


@cocotb.test()
async def test_gpio_ral_out_readback_and_inputs(dut):
    await reset(dut)

    # write outputs via the model's write view
    await apb_write(dut, gpio.io.offset, gpio.io.encode(out=0b1010))
    for _ in range(3):
        await RisingEdge(dut.PCLK)
    rd = await apb_read(dut, gpio.io.offset)
    gpio.io.check(rd, out_rdbk=0b1010)
    assert int(dut.gpio_out.value) == 0b1010, "pins must match written value"

    # drive inputs, allow 2-FF synchroniser to settle, read via model
    dut.gpio_in.value = 0b11
    for _ in range(4):
        await RisingEdge(dut.PCLK)
    rd = await apb_read(dut, gpio.io.offset)
    gpio.io.check(rd, inputs=0b11, out_rdbk=0b1010)

    cocotb.log.info("*** GPIO RAL out/readback/inputs PASS ***")


@cocotb.test()
async def test_gpio_unused_bits_read_zero(dut):
    """Bits above the defined fields must read as 0 (reserved-as-zero)."""
    await reset(dut)
    await apb_write(dut, gpio.io.offset, gpio.io.encode(out=0b1111))
    dut.gpio_in.value = 0b11
    for _ in range(4):
        await RisingEdge(dut.PCLK)
    rd = await apb_read(dut, gpio.io.offset)
    used = gpio.io.rfields["inputs"].mask | gpio.io.rfields["out_rdbk"].mask
    assert rd & ~used == 0, \
        f"reserved bits nonzero: read=0x{rd:08x} used-mask=0x{used:08x}"
    cocotb.log.info("*** GPIO unused-bits-read-zero PASS ***")
