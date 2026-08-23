"""AHB NONSEQ write → APB SETUP/ACCESS."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ReadOnly

@cocotb.test()
async def test_bridge_write(dut):
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

    # Drive address phase for a full cycle
    dut.HSEL.value = 1
    dut.HTRANS.value = 0b10
    dut.HWRITE.value = 1
    dut.HADDR.value = 0x00020004
    await Timer(1, unit="ns")  # settle
    await RisingEdge(dut.HCLK)  # IDLE samples ahb_access → next=SETUP
    # SETUP cycle now
    dut.HWDATA.value = 0xA5
    await Timer(1, unit="ns")
    cocotb.log.info(f"SETUP: PSEL={int(dut.PSEL.value)} PENABLE={int(dut.PENABLE.value)} HREADY={int(dut.HREADY.value)}")
    assert int(dut.PSEL.value) == 1, "expected SETUP PSEL"
    assert int(dut.PENABLE.value) == 0

    await RisingEdge(dut.HCLK)  # → ACCESS
    # deassert master after data phase starts
    dut.HSEL.value = 0
    dut.HTRANS.value = 0
    await Timer(1, unit="ns")
    cocotb.log.info(
        f"ACCESS: PSEL={int(dut.PSEL.value)} PEN={int(dut.PENABLE.value)} "
        f"PWRITE={int(dut.PWRITE.value)} PADDR=0x{int(dut.PADDR.value):08x} "
        f"PWDATA=0x{int(dut.PWDATA.value):x} HREADY={int(dut.HREADY.value)}"
    )
    assert int(dut.PSEL.value) == 1
    assert int(dut.PENABLE.value) == 1
    assert int(dut.PWRITE.value) == 1
    assert int(dut.PADDR.value) == 0x00020004
    assert int(dut.PWDATA.value) == 0xA5
    assert int(dut.HREADY.value) == 1
    cocotb.log.info("*** bridge write PASS ***")
