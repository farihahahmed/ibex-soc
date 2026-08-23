"""CR: several random APB SPI writes; MOSI must match each byte."""
import os
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from pyuvm import uvm_test, uvm_sequencer, uvm_sequence, uvm_root
from tb.agents.apb import ApbItem, ApbDriver
from tb.agents.apb import dut_handle


class WriteSeq(uvm_sequence):
    def __init__(self, name, data):
        super().__init__(name)
        self.data = data

    async def body(self):
        item = ApbItem("w", write=True, addr=0, data=self.data)
        await self.start_item(item)
        await self.finish_item(item)


async def capture_mosi(dut):
    captured = 0
    bits = 0
    await FallingEdge(dut.cs_n)
    while bits < 8:
        await RisingEdge(dut.sclk)
        captured = ((captured << 1) | (int(dut.mosi.value) & 1)) & 0xFF
        bits += 1
    return captured


class SpiRandomTest(uvm_test):
    def build_phase(self):
        self.seqr = uvm_sequencer("seqr", self)
        self.driver = ApbDriver("driver", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)

    async def run_phase(self):
        self.raise_objection()
        seed = int(os.environ.get("RANDOM_SEED", "42"))
        random.seed(seed)
        vals = [random.randint(0, 255) for _ in range(5)]
        self.logger.info(f"seed={seed} vals={[hex(v) for v in vals]}")
        dut = dut_handle.DUT
        for v in vals:
            # wait idle (cs high)
            for _ in range(50):
                await RisingEdge(dut.PCLK)
                if int(dut.cs_n.value) == 1:
                    break
            mon = cocotb.start_soon(capture_mosi(dut))
            await WriteSeq("w", v).start(self.seqr)
            got = await mon
            assert got == v, f"got 0x{got:02x} expect 0x{v:02x}"
            self.logger.info(f"OK 0x{v:02x}")
        self.logger.info(f"*** SPI CR PASS seed={seed} ***")
        self.drop_objection()


@cocotb.test()
async def test_spi_random(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    dut.PRESETn.value = 0
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = 0
    dut.PWDATA.value = 0
    dut.miso.value = 0
    await Timer(50, unit="ns")
    dut.PRESETn.value = 1
    for _ in range(5):
        await RisingEdge(dut.PCLK)
    dut_handle.DUT = dut
    await uvm_root().run_test("SpiRandomTest")
