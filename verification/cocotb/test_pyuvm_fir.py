"""FIR filter on the MAC accelerator - the DSP capability, demonstrated.

fir_demo.bin runs a 5-tap moving-average filter (taps 1,2,4,2,1, unity DC
gain) over a noisy square wave using the custom mac/macclr instructions, and
prints raw,filtered pairs over UART.

The input is a +-100 square wave carrying +-30 alternating noise. A working
filter cuts the steady-state ripple to +-6 while preserving amplitude - a 5x
noise reduction. This test checks every output value against a Python model of
the same filter and reports the measured reduction.

The samples are generated arithmetically rather than captured from a sensor:
this tapeout has no analog input and no SPI MISO pin, so there is no path for
external data. The filter arithmetic is real; the stimulus is synthetic.
"""
import cocotb
from cocotb.triggers import Timer
from pyuvm import uvm_test, uvm_root
from tb.env import IbexSocEnv
from tb.sequences.firmware_seq import LoadFirmwareSeq
from tb import dut_handle
from common import init_dut

TAPS = [1, 2, 4, 2, 1]


def sample(i):
    if i < 0:
        return 0
    return (-100 if (i // 8) % 2 else 100) + (-30 if i % 2 else 30)


def expected(i):
    acc = sum(TAPS[k] * sample(i - k) for k in range(5))
    return acc // 10 if acc >= 0 else -((-acc) // 10)


class PyuvmFirTest(uvm_test):
    def build_phase(self):
        self.env = IbexSocEnv.create("env", self)

    async def run_phase(self):
        self.raise_objection()
        seq = LoadFirmwareSeq("fir", "../../firmware/fir_demo.bin")
        await seq.start(self.env.scan_agent.sequencer)
        self.env.scoreboard.require_events = {"program_loaded", "cpu_started"}

        await Timer(3000000, unit="ns")

        text = "".join(chr(b) for b in self.env.scoreboard.seen_uart
                       if 32 <= b < 127).strip()
        self.logger.info(f"UART: {text}")

        pairs = [p for p in text.split() if "," in p]
        assert len(pairs) >= 16, f"expected at least 16 pairs, got {len(pairs)}: {text!r}"

        raw, filt = [], []
        for n, p in enumerate(pairs):
            r, f = p.split(",")
            r, f = int(r), int(f)
            assert r == sample(n), f"sample {n}: raw {r} != expected {sample(n)}"
            assert f == expected(n), \
                f"sample {n}: filtered {f} != model {expected(n)}"
            raw.append(r); filt.append(f)

        # Steady-state ripple, skipping the settling window after each edge.
        def ripple(sig):
            d = [abs(sig[i] - (100 if (i // 8) % 2 == 0 else -100))
                 for i in range(len(sig)) if (i % 8) >= 5]
            return sum(d) / len(d) if d else 0.0

        rr, rf = ripple(raw), ripple(filt)
        self.logger.info("")
        self.logger.info(f"  5-tap FIR over {len(pairs)} samples, taps {TAPS}")
        self.logger.info(f"    steady-state ripple, raw       {rr:5.1f}")
        self.logger.info(f"    steady-state ripple, filtered  {rf:5.1f}")
        self.logger.info(f"    noise reduction                {rr/rf:5.1f}x")
        self.logger.info("")

        assert rf < rr / 2, f"filter should at least halve the ripple: {rr} -> {rf}"
        self.logger.info("*** MAC FIR filter PASS ***")
        self.drop_objection()


@cocotb.test()
async def test_pyuvm_fir(dut):
    await init_dut(dut)
    dut_handle.DUT = dut
    await uvm_root().run_test("PyuvmFirTest")
