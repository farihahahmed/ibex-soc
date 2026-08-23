"""AHB NONSEQ read → HRDATA tracks PRDATA in ACCESS."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_bridge_read(dut):
    cocotb.start_soon(Clock(dut.HCLK, 10, unit="ns").start())
    dut.HRESETn.value = 0
    dut.HSEL.value = 0
    dut.HADDR.value = 0
    dut.HTRANS.value = 0
    dut.HWRITE.value = 0
    dut.HWDATA.value = 0
    dut.PRDATA.value = 0x5A
    dut.PREADY.value = 1
    await Timer(40, unit="ns")
    dut.HRESETn.value = 1
    await RisingEdge(dut.HCLK)
    await RisingEdge(dut.HCLK)

    dut.HSEL.value = 1
    dut.HTRANS.value = 0b10
    dut.HWRITE.value = 0
    dut.HADDR.value = 0x00020000
    await Timer(1, unit="ns")
    await RisingEdge(dut.HCLK)  # → SETUP
    await Timer(1, unit="ns")
    assert int(dut.PSEL.value) == 1
    assert int(dut.PENABLE.value) == 0

    await RisingEdge(dut.HCLK)  # → ACCESS
    dut.HSEL.value = 0
    dut.HTRANS.value = 0
    await Timer(1, unit="ns")
    assert int(dut.PSEL.value) == 1
    assert int(dut.PENABLE.value) == 1
    assert int(dut.PWRITE.value) == 0
    assert int(dut.HRDATA.value) == 0x5A
    assert int(dut.HREADY.value) == 1
    cocotb.log.info("*** bridge read PASS ***")
