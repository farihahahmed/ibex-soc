"""AHB response mux: data phase uses region_q (one cycle after address)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

CASES = [
    (0x00000010, 0, 0xA0A0_0000),
    (0x00010000, 1, 0xA1A1_0000),
    (0x00020000, 2, 0xA2A2_0000),
    (0x00030000, 3, 0xA3A3_0000),
]

@cocotb.test()
async def test_ahb_mux(dut):
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

    for addr, idx, tag in CASES:
        for i in range(4):
            getattr(dut, f"s{i}_HRDATA").value = tag if i == idx else 0xDEAD_BEEF

        # address phase
        dut.HADDR.value = addr
        dut.HTRANS.value = 0b10
        await RisingEdge(dut.HCLK)   # region_q captures
        # data phase
        await RisingEdge(dut.HCLK)   # mux uses region_q
        rd = int(dut.HRDATA.value)
        cocotb.log.info(f"slave{idx} HRDATA=0x{rd:08x} expect=0x{tag:08x}")
        assert rd == tag

        dut.HTRANS.value = 0  # IDLE between transfers
        await RisingEdge(dut.HCLK)

    cocotb.log.info("*** ahb mux PASS ***")
