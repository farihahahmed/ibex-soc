# Memory Map

Every device shares the CPU's data port and is selected by address. The bus decodes the address and routes the request to the matching device.

| Device | Start | End | Size |
|--------|-------|-----|------|
| Instruction memory | `0x0000_0000` | `0x0000_07FF` | 2 KB |
| Data memory | `0x0000_0800` | `0x0000_0FFF` | 2 KB |
| GPIO | `0x0001_0000` | `0x0001_000F` | 16 B |
| UART | `0x0002_0000` | `0x0002_000F` | 16 B |
| SPI | `0x0003_0000` | `0x0003_00FF` | 256 B |

This table is the single source of truth. It must match the bus decoder (RTL), the linker script, and the software.
