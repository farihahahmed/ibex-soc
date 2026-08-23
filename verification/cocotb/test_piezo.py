import cocotb
from cocotb.triggers import Timer
from pathlib import Path
from common import init_dut, load_program, start_cpu
from coverage import cov

def load_bin_as_words(path):
    data = Path(path).read_bytes()
    while len(data) % 4:
        data += b'\x00'
    words = []
    for i in range(0, len(data), 4):
        w = data[i] | (data[i+1] << 8) | (data[i+2] << 16) | (data[i+3] << 24)
        words.append(w)
    return words


@cocotb.test()
async def test_piezo(dut):
    """Load piezo_tune.bin and check GPIO[0] toggles"""

    await init_dut(dut)
    cov.hit("piezo_start")

    toggle_count = 0

    async def gpio_toggle_counter():
        nonlocal toggle_count
        last = int(dut.gpio_out.value) & 1
        while True:
            await dut.gpio_out.value_change
            cur = int(dut.gpio_out.value) & 1
            if cur != last:
                toggle_count += 1
                last = cur

    cocotb.start_soon(gpio_toggle_counter())

    words = load_bin_as_words("../../firmware/piezo_tune.bin")
    cocotb.log.info(f"Loading piezo_tune.bin ({len(words)} words)")
    await load_program(dut, words)
    await start_cpu(dut)
    cocotb.log.info("piezo running – counting GPIO toggles (longer run)...")

    # Musical delays are long; give it more time
    await Timer(2000000, unit="ns")   # 2 ms

    cocotb.log.info(f"GPIO[0] toggles observed: {toggle_count}")
    assert toggle_count >= 2, f"Expected meaningful activity, got {toggle_count}"

    cov.hit("piezo_toggles", toggle_count)
    cov.hit("piezo_passed")
    cov.report()
    cocotb.log.info("*** PASS: piezo_tune produced GPIO activity ***")
