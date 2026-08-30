# Memory Map

Every device shares the CPU's data port and is selected by address. The bus
decodes `HADDR[17:16]` and routes the request to the matching device:
`00` = memory, `01` = GPIO, `10` = UART, `11` = SPI.

| Device | Start | End | Size | Physical macro |
|--------|-------|-----|------|----------------|
| Instruction memory | `0x0000_0000` | `0x0000_01FF` | 512 B | 1× 512×8 SRAM (narrow) |
| Data memory | `0x0000_0000` (AHB slave) | `0x0000_01FF` | 512 B | 1× 512×8 SRAM (narrow) |
| GPIO | `0x0001_0000` | `0x0001_000F` | 16 B | 2 in / 4 out |
| UART | `0x0002_0000` | `0x0002_000F` | 16 B | — |
| SPI | `0x0003_0000` | `0x0003_00FF` | 256 B | — |

Instruction and data memory both start at `0x0` because instruction fetches
never reach the AHB bus: `pico_shim` splits the CPU's unified port, routing
fetches directly to the instruction memory and data accesses to the bus.

**Boot.** PicoRV32 boots at `0x0` (`PROGADDR_RESET = 0`). Programs are linked
at `0x0` (`firmware/link.ld`, `_start` placed first via `.text.start`) and
scan-loaded starting at word 0.

**Stack.** `STACKADDR = 0x200` — the stack pointer initialises to the top of
the 512 B data memory and grows down.

**UART registers.**

- `0x0002_0000` STATUS (read): bit0 = tx_busy, bit1 = rx_valid (peek, no clear)
- `0x0002_0004` DATA: write = transmit byte; read = rx byte (clears rx_valid)

Firmware must poll STATUS bit0 before each write (`putc` busy-waits) —
PicoRV32 issues back-to-back stores faster than the UART shifts bits out.

This table is the single source of truth. It must match the bus decoder
(`rtl/ahb_interconnect.sv`), the linker script, and the software.

## Narrow-memory note

The instruction and data memories are **8-bit-wide "narrow" memories**: each is
a single 8-bit SRAM macro fronted by a byte gather/scatter unit that presents a
normal 32-bit memory to the CPU. A conventional 32-bit memory would need four
SRAM macros per bank; this design uses one, which is a key area lever.

Each memory is addressed with 9 bits (`ADDR_BITS = 9`), giving 512 bytes.
All three demo firmwares fit comfortably — the largest is 172 B.

## History

The v1 signoff used 256 B instruction and 64 B data memory on a 1000 × 1000 µm
die. Growing the die to the full 1110 × 1110 A45 slot freed enough area to
triple total memory to 1 KB while keeping the full RV32E+M+C core. See `FRONTEND_SYNTHESIS.md`.
