# PCPI Accelerator — Benchmarks

Custom single-cycle instructions on PicoRV32's PCPI interface (custom-0 opcode
`0x0B`). All figures below are **measured on the gate-level SoC in cocotb**, not
estimated, and reproduce from the verification gate.

## CRC32 — 10.34× faster

Folding 64 bytes through CRC32 over identical data: a software bitwise loop
versus the custom `crc32.b` instruction. The software baseline is the bitwise
loop, not a table lookup, because a table-driven CRC needs a 1 KB table that
does not fit this chip's 512 B of data memory — so it is the realistic
baseline, not a strawman.

| Path | Cycles |
| --- | ---: |
| Software (bitwise loop) | 39,143 |
| Custom `crc32.b` | 3,785 |
| **Speedup** | **10.34×** |

Cycles are counted by the testbench: PicoRV32 is built without a cycle counter
(`ENABLE_COUNTERS=0`), so the firmware raises a GPIO marker around each region
and the testbench counts clock edges while it is high.

Reproduce:
cd verification/cocotb && COCOTB_TEST_MODULES=test_pyuvm_cycles make

## FIR filter (signed MAC) — 5× noise reduction

A 5-tap moving-average filter (taps 1-2-4-2-1, unity DC gain) over a noisy
±100 square wave with ±30 alternating noise, built on the custom signed
`mac` / `macrd` / `macclr` instructions. Steady-state ripple drops from 30 to 6
while the square wave's amplitude is preserved.

| Metric | Value |
| --- | ---: |
| Raw ripple | 30.0 |
| Filtered ripple | 6.0 |
| **Noise reduction** | **5.0×** |

Reproduce:
cd verification/cocotb && COCOTB_TEST_MODULES=test_pyuvm_fir make

## Correctness — all 7 instructions

`crc32.b`, `crc32.w`, `popcnt`, `brev`, `mac`, `macrd`, `macclr` are each
checked against a Python golden model (`test_pyuvm_pcpi`, firmware
`pcpi_demo.c`). CRC uses the reflected IEEE 802.3 polynomial `0xEDB88320`, so
results match zlib and Ethernet.

Seven formal properties (`verification/formal/pcpi_formal.sv`) prove the
handshake discipline: an unclaimed `funct3` never raises `pcpi_ready`,
`pcpi_wr == pcpi_ready`, single-cycle completion, `pcpi_wait` tied low.

## Summary

| Workload | Software | Custom | Gain |
| --- | ---: | ---: | ---: |
| CRC32 (64 B) | 39,143 cyc | 3,785 cyc | **10.3× faster** |
| FIR ripple | 30.0 | 6.0 | **5× cleaner** |
