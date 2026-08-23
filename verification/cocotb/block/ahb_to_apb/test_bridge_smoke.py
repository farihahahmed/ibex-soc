"""ahb_to_apb: reset → IDLE, HREADY=1, no APB activity."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_bridge_smoke(dut):
    cocotb.start_soon(Clock(dut.HCLK, 10, unit="ns").start())
    dut.HRESETn.value = 0
    dut.HSEL.value = 0
    dut.HADDR.value = 0
    dut.HTRANS.value = 0
    dut.HWRITE.value = 0
    dut.HWDATA.value = 0
    dut.PRDATA.value = 0
    dut.PREADY.value = 1
    await Timer(40, unit="ns")
    dut.HRESETn.value = 1
    await RisingEdge(dut.HCLK)
    await RisingEdge(dut.HCLK)

    assert int(dut.HREADY.value) == 1
    assert int(dut.PSEL.value) == 0
    assert int(dut.PENABLE.value) == 0
    assert int(dut.HRESP.value) == 0
    cocotb.log.info("*** bridge smoke PASS ***")
