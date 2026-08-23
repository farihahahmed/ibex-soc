import os
import random
import cocotb
from cocotb.triggers import Timer
from common import init_dut, load_program, start_cpu
from vip import GpioMonitor
from coverage import cov

def make_gpio_program(val):
    imm = val & 0x1F
    return [
        0x00010537,
        0x00000093 | ((imm & 0xFFF) << 20),
        0x00152023,
        0x00000013,
        0xFFDFF06F,
    ]

@cocotb.test()
async def test_random_gpio(dut):
    seed = int(os.environ.get("RANDOM_SEED", "42"))
    random.seed(seed)
    val = random.randint(1, 31)

    cocotb.log.info(f"Seed={seed}  Random GPIO under test: 0x{val:02x}")

    await init_dut(dut)

    gpio_mon = GpioMonitor(dut)
    cocotb.start_soon(gpio_mon.run())

    await load_program(dut, make_gpio_program(val))
    await start_cpu(dut)

    await Timer(15000, unit="ns")

    observed = gpio_mon.get_final()
    cocotb.log.info(f"Observed GPIO = 0x{observed:02x}")

    cov.hit("random_gpio_value", observed)
    assert observed == val, f"Seed {seed}: expected 0x{val:02x}, got 0x{observed:02x}"

    cov.hit("random_test_passed")
    cov.report()
    cocotb.log.info(f"*** PASS: seed={seed} GPIO=0x{val:02x} ***")
