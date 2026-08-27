"""Phase 5: real piezo_tune.bin under pyuvm."""
import cocotb
from cocotb.triggers import RisingEdge
from pyuvm import uvm_test, uvm_root
from tb.env import PicoSocEnv
from tb.sequences.firmware_seq import LoadFirmwareSeq
from tb import dut_handle
from common import init_dut

class PyuvmPiezoTest(uvm_test):
    def build_phase(self):
        self.env = PicoSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        self.env.scoreboard.require_events = {
            "program_loaded", "cpu_started"
        }
        seq = LoadFirmwareSeq("load", "../../firmware/piezo_tune.bin")
        await seq.start(self.env.scan_agent.sequencer)

        dut = dut_handle.DUT
        toggles = 0
        last = int(dut.gpio_out.value) & 1
        trap = 0
        for i in range(50000):
            await RisingEdge(dut.clk)
            cur = int(dut.gpio_out.value) & 1
            if cur != last:
                toggles += 1
                last = cur
            try:
                trap = int(dut.u_cpu.trap.value)
            except Exception:
                pass
            if trap:
                break
            if toggles >= 20:
                break

        self.logger.info(f"toggles={toggles} trap={trap}")
        assert trap == 0, "CPU trapped – piezo FW still broken"
        assert toggles >= 10, f"Expected piezo toggles, got {toggles}"
        self.logger.info("*** pyuvm piezo (real bin) PASS ***")
        self.drop_objection()

@cocotb.test()
async def test_pyuvm_piezo(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmPiezoTest")
