"""dmem: write word @0x10, read back — proves gather/scatter path."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

async def reset(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.req.value = 0
    dut.we.value = 0
    dut.be.value = 0
    dut.addr.value = 0
    dut.wdata.value = 0
    dut.ld_word_en.value = 0
    dut.ld_word_addr.value = 0
    dut.ld_word_data.value = 0
    for _ in range(4):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)

async def xfer(dut, we, addr, data=0, be=0xF, timeout=40):
    """Issue one req; wait gnt then rvalid; return rdata."""
    await RisingEdge(dut.clk)
    dut.addr.value = addr
    dut.wdata.value = data
    dut.be.value = be
    dut.we.value = we
    dut.req.value = 1
    # wait grant
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if int(dut.gnt.value):
            break
    else:
        raise AssertionError("timeout waiting gnt")
    dut.req.value = 0
    dut.we.value = 0
    # wait rvalid
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if int(dut.rvalid.value):
            return int(dut.rdata.value)
    raise AssertionError("timeout waiting rvalid")

@cocotb.test()
async def test_dmem_word(dut):
    await reset(dut)
    val = 0xA5C33715
    await xfer(dut, we=1, addr=0x10, data=val, be=0xF)
    rdata = await xfer(dut, we=0, addr=0x10, be=0xF)
    cocotb.log.info(f"wrote 0x{val:08x} read 0x{rdata:08x}")
    assert rdata == val, f"mismatch: got 0x{rdata:08x}"
    cocotb.log.info("*** dmem word PASS ***")
