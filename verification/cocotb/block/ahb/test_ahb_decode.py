"""AHB decode: HADDR[17:16] + HTRANS[1] → one-hot HSEL."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

REGIONS = [
    (0x00000010, 0b0001),  # mem
    (0x00010000, 0b0010),  # GPIO
    (0x00020000, 0b0100),  # UART
    (0x00030000, 0b1000),  # SPI
]

@cocotb.test()
async def test_ahb_decode(dut):
    cocotb.start_soon(Clock(dut.HCLK, 10, unit="ns").start())
    dut.HRESETn.value = 0
    dut.HADDR.value = 0
    dut.HTRANS.value = 0
    dut.HWRITE.value = 0
    dut.HWDATA.value = 0
    for i in range(4):
        getattr(dut, f"s{i}_HRDATA").value = 0
        getattr(dut, f"s{i}_HREADY").value = 1
        getattr(dut, f"s{i}_HRESP").value = 0
    for _ in range(4):
        await RisingEdge(dut.HCLK)
    dut.HRESETn.value = 1
    await RisingEdge(dut.HCLK)

    for addr, expect in REGIONS:
        dut.HADDR.value = addr
        dut.HTRANS.value = 0b10  # NONSEQ
        await RisingEdge(dut.HCLK)
        hsel = int(dut.HSEL.value)
        cocotb.log.info(f"addr=0x{addr:08x} HSEL=0b{hsel:04b} expect=0b{expect:04b}")
        assert hsel == expect

    # IDLE clears select
    dut.HTRANS.value = 0
    await RisingEdge(dut.HCLK)
    assert int(dut.HSEL.value) == 0
    cocotb.log.info("*** ahb decode PASS ***")
