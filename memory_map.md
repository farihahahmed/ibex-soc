# Memory Map

Every device shares the CPU's data port and is selected by address. The bus decodes the address and routes the request to the matching device.

| Device | Start | End | Size | Physical macro |
|--------|-------|-----|------|----------------|
| Instruction memory | `0x0000_0000` | `0x0000_01FF` | 512 B | 1× 512×8 SRAM (narrow) |
| Data memory | `0x0000_0000` (AHB slave) | `0x0000_003F` | 64 B | 1× 64×8 SRAM (narrow) |
| GPIO | `0x0001_0000` | `0x0001_000F` | 16 B | — |
| UART | `0x0002_0000` | `0x0002_000F` | 16 B | — |
| SPI | `0x0003_0000` | `0x0003_00FF` | 256 B | — |

The bus decodes `HADDR[17:16]`: `00`=memory, `01`=GPIO, `10`=UART, `11`=SPI.
Ibex boots at `boot_addr + 0x80`, so programs load starting at byte `0x80`
(word index 32).

This table is the single source of truth. It must match the bus decoder (RTL),
the linker script, and the software.

## Narrow-memory note (why the sizes are small)

The instruction and data memories are **8-bit-wide "narrow" memories**: each is a
single 8-bit SRAM macro fronted by a byte gather/scatter unit that makes it look
like a normal 32-bit memory to the CPU. This is the key area lever that lets the
whole chip fit in 1 mm² — a conventional 32-bit memory needs four SRAM macros per
bank and does not fit. See `AREA_REPORT.md` for the full reasoning.

Practical consequence: the **address map is unchanged** (the CPU sees the same
addresses as a normal memory), but the **capacities are smaller** — 512 B of
instruction memory and 64 B of data memory. Programs must fit in 512 B of code;
the demo programs use ~0 bytes of data memory (all scalars live in registers), so
64 B of scratch is ample. A larger memory would just use a deeper single macro
(e.g. 128×8 or 256×8) — still one macro, minimal area change.

The data memory is implemented as the AHB slave `ahb_mem` (the CPU's data port
reaches it over the AHB bus: Ibex → ibex_to_ahb → ahb_interconnect → ahb_mem).
Because the narrow memory is multi-cycle, `ahb_mem` inserts AHB wait-states
(holds `HREADY` low) until each access completes.
