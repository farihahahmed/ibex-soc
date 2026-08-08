# Firmware

RISC-V demo programs for the SoC, matching the three Columbia demo options.
Compiled with the RV32IMC toolchain, converted to scan-loadable hex words,
and loaded over the scan chain. Each fits the **256 B** instruction memory;
stacks stay within the 64 B data memory (STACKADDR=0x40, grows down).

| File | Size | Demo | Drives | Verified on PicoRV32 |
|------|-----:|------|--------|----------------------|
| `primes.c` | 126 B | primes streamed to a PC terminal (MUL/MOD) | UART tx | prints 2 3 5 … 47 ✅ |
| `piezo_tune.c` | 122 B | "Happy Birthday" tone | GPIO out[0] (piezo) | 1018 toggles ✅ |
| `game.c` | 130 B | dodge game on an SPI LCD | SPI sclk/mosi | 15,376 SCLK toggles ✅ |

`link.ld` places code at **0x0** (PicoRV32 PROGADDR_RESET=0x0); `_start` is
pinned first via the `.text.start` section. UART output uses a busy-wait
`putc`: poll STATUS (0x2_0000) bit0, then write DATA (0x2_0004).

## Build

```bash
riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -nostdlib -ffreestanding \
  -nostartfiles -T link.ld primes.c -o primes.elf
riscv64-unknown-elf-objcopy -O binary primes.elf primes.bin
# split into 32-bit little-endian words -> primes.hex
```

## Run in simulation

`tb/tb_demo.sv` scan-loads a program (from the matching `tb/g_*_prog.svh`),
configures the FSM to RUN, and checks peripheral pin activity. All three
demos are verified on the final PicoRV32 design.
