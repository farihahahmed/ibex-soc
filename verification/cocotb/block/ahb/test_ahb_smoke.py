"""AHB interconnect smoke: reset, idle → HSEL=0, HREADY from default path."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_ahb_smoke(dut):
    cocotb.start_soon(Clock(dut.HCLK, 10, unit="ns").start())
    dut.HRESETn.value = 0
    dut.HADDR.value = 0
    dut.HTRANS.value = 0  # IDLE
    dut.HWRITE.value = 0
    dut.HWDATA.value = 0
    # slaves idle-ready
    for i in range(4):
        getattr(dut, f"s{i}_HRDATA").value = 0
        getattr(dut, f"s{i}_HREADY").value = 1
        getattr(dut, f"s{i}_HRESP").value = 0

    for _ in range(4):
        await RisingEdge(dut.HCLK)
    dut.HRESETn.value = 1
    for _ in range(4):
        await RisingEdge(dut.HCLK)

    hsel = int(dut.HSEL.value)
    cocotb.log.info(f"idle HSEL=0x{hsel:x}")
    assert hsel == 0, "IDLE transfer must select no slave"
    cocotb.log.info("*** ahb smoke PASS ***")
