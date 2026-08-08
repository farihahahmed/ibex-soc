# Memory Map

Every device shares the CPU's data port and is selected by address. The bus
decodes the address and routes the request to the matching device.

| Device | Start | End | Size | Physical macro |
|--------|-------|-----|------|----------------|
| Instruction memory | `0x0000_0000` | `0x0000_00FF` | 256 B | 1× 256×8 SRAM (narrow) |
| Data memory | `0x0000_0000` (AHB slave) | `0x0000_003F` | 64 B | 1× 64×8 SRAM (narrow) |
| GPIO | `0x0001_0000` | `0x0001_000F` | 16 B | 2 in / 5 out |
| UART | `0x0002_0000` | `0x0002_000F` | 16 B | — |
| SPI | `0x0003_0000` | `0x0003_00FF` | 256 B | — |

The bus decodes `HADDR[17:16]`: `00`=memory, `01`=GPIO, `10`=UART, `11`=SPI.

**Boot:** PicoRV32 boots at `0x0` (PROGADDR_RESET=0). Programs are linked at
`0x0` (`firmware/link.ld`, `_start` placed first via `.text.start`) and
scan-loaded starting at word 0. The stack pointer starts at `0x40` (top of
dmem) and grows down.

**UART registers:**
- `0x0002_0000` STATUS (read): bit0 = tx_busy, bit1 = rx_valid (peek, no clear)
- `0x0002_0004` DATA: write = transmit byte; read = rx byte (clears rx_valid)

Firmware must poll STATUS bit0 before each write (`putc` busy-waits) —
PicoRV32 issues back-to-back stores faster than the UART shifts bits out.

This table is the single source of truth. It must match the bus decoder (RTL),
the linker script, and the software.

## Narrow-memory note (why the sizes are small)

The instruction and data memories are **8-bit-wide "narrow" memories**: each is
a single 8-bit SRAM macro fronted by a byte gather/scatter unit that makes it
look like a normal 32-bit memory to the CPU. This is a key area lever for the
1 mm² die — a conventional 32-bit memory needs four SRAM macros per bank.

Capacities: **256 B** instruction, **64 B** data. Programs must fit in 256 B of
code; all three demo firmwares (game 130 B, primes 126 B, piezo_tune 122 B) fit,
and their stacks stay within the 64 B dmem (verified: lowest stack write 0x14).
