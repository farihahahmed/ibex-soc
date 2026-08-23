"""dmem byte-enable: write 0xFFFFFFFF, then overwrite only byte1 with 0xAA."""
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
    await RisingEdge(dut.clk)
    dut.addr.value = addr
    dut.wdata.value = data
    dut.be.value = be
    dut.we.value = we
    dut.req.value = 1
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if int(dut.gnt.value):
            break
    else:
        raise AssertionError("timeout gnt")
    dut.req.value = 0
    dut.we.value = 0
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if int(dut.rvalid.value):
            return int(dut.rdata.value)
    raise AssertionError("timeout rvalid")

@cocotb.test()
async def test_dmem_be(dut):
    await reset(dut)
    # seed full word
    await xfer(dut, we=1, addr=0x08, data=0xFFFFFFFF, be=0xF)
    # overwrite only byte lane 1 (bits 15:8)
    await xfer(dut, we=1, addr=0x08, data=0x0000AA00, be=0x2)
    rdata = await xfer(dut, we=0, addr=0x08, be=0xF)
    expect = 0xFFFFAAFF
    cocotb.log.info(f"after BE write read=0x{rdata:08x} expect=0x{expect:08x}")
    assert rdata == expect, f"BE fail got 0x{rdata:08x}"
    cocotb.log.info("*** dmem BE PASS ***")
