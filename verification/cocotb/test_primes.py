import cocotb
from cocotb.triggers import Timer, ClockCycles, RisingEdge
from pathlib import Path
from common import init_dut, load_program, start_cpu
from vip import UartMonitor
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
async def test_primes(dut):
    """Load primes.bin and check UART prints prime numbers"""

    await init_dut(dut)
    cov.hit("primes_start")

    uart_mon = UartMonitor(dut, bit_cycles=8)
    cocotb.start_soon(uart_mon.run())

    words = load_bin_as_words("../../firmware/primes.bin")
    cocotb.log.info(f"Loading primes.bin ({len(words)} words)")
    await load_program(dut, words)
    await start_cpu(dut)
    cocotb.log.info("primes running – waiting for UART output...")

    # Give it time to print several primes (MUL/DIV is slow on Pico)
    await Timer(500000, unit="ns")   # 0.5 ms sim time

    received = "".join(chr(b) for b in uart_mon.bytes if 32 <= b < 127)
    cocotb.log.info(f"UART received: '{received}'")

    # Must contain at least the first few primes
    assert "2" in received, "Did not see prime '2'"
    assert "3" in received, "Did not see prime '3'"
    assert "5" in received, "Did not see prime '5'"

    cov.hit("primes_uart_ok")
    cov.hit("primes_passed")
    cov.report()
    cocotb.log.info("*** PASS: primes firmware produced expected UART output ***")
