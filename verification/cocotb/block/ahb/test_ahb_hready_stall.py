"""AHB: slave HREADY=0 must appear on master HREADY (stall path)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_ahb_hready_stall(dut):
    cocotb.start_soon(Clock(dut.HCLK, 10, unit="ns").start())
    dut.HRESETn.value = 0
    dut.HADDR.value = 0
    dut.HTRANS.value = 0
    dut.HWRITE.value = 0
    dut.HWDATA.value = 0
    # idle slaves ready
    for i in range(4):
        getattr(dut, f"s{i}_HRDATA").value = 0
        getattr(dut, f"s{i}_HREADY").value = 1
        getattr(dut, f"s{i}_HRESP").value = 0
    for _ in range(4):
        await RisingEdge(dut.HCLK)
    dut.HRESETn.value = 1
    await RisingEdge(dut.HCLK)

    # address phase: region 0 (mem), NONSEQ
    dut.HADDR.value = 0x00000000
    dut.HTRANS.value = 0b10  # NONSEQ
    await RisingEdge(dut.HCLK)

    # data phase for that transfer: force s0 not ready
    dut.HTRANS.value = 0  # IDLE next
    dut.s0_HREADY.value = 0
    await RisingEdge(dut.HCLK)
    await Timer(1, unit="ns")
    hready = int(dut.HREADY.value)
    cocotb.log.info(f"during stall HREADY={hready}")
    assert hready == 0, "master HREADY should be 0 when s0 stalls"

    # release
    dut.s0_HREADY.value = 1
    await RisingEdge(dut.HCLK)
    await Timer(1, unit="ns")
    assert int(dut.HREADY.value) == 1
    cocotb.log.info("*** ahb HREADY stall PASS ***")
