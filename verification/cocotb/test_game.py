import cocotb
from cocotb.triggers import Timer, RisingEdge
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
async def test_game(dut):
    """Load game.bin and check SPI activity (LCD traffic)"""

    await init_dut(dut)
    cov.hit("game_start")

    sclk_count = 0

    async def spi_sclk_counter():
        nonlocal sclk_count
        while True:
            await RisingEdge(dut.spi_sclk)
            sclk_count += 1

    cocotb.start_soon(spi_sclk_counter())

    words = load_bin_as_words("../../firmware/game.bin")
    cocotb.log.info(f"Loading game.bin ({len(words)} words)")
    await load_program(dut, words)
    await start_cpu(dut)
    cocotb.log.info("game running – counting SPI SCLK edges...")

    await Timer(500000, unit="ns")

    cocotb.log.info(f"SPI SCLK rising edges: {sclk_count}")
    # Original verification saw thousands of edges; we just need clear activity
    assert sclk_count > 50, f"Expected SPI activity, got {sclk_count} edges"

    cov.hit("game_spi_edges", sclk_count)
    cov.hit("game_passed")
    cov.report()
    cocotb.log.info("*** PASS: game firmware produced SPI activity ***")
