# Firmware

RISC-V demo programs for the SoC. Compiled for **RV32E + M + C**, converted to
scan-loadable hex words, and loaded over the scan chain. Each fits the **512 B**
instruction memory; the stack starts at the top of the 512 B data memory
(`STACKADDR = 0x200`) and grows down.

| File | Size | Words | Demo | Drives |
|------|-----:|------:|------|--------|
| `primes.c` | 116 B | 29 | primes streamed to a terminal (MUL/DIV/MOD) | UART tx |
| `piezo_tune.c` | 172 B | 43 | "Happy Birthday" tone | GPIO out[0] (piezo) |
| `game.c` | 122 B | 31 | dodge game on an SPI LCD | SPI sclk/mosi |

`link.ld` places code at **0x0** (`PROGADDR_RESET = 0x0`); `_start` is pinned
first via the `.text.start` section. UART output uses a busy-wait `putc`: poll
STATUS (`0x2_0000`) bit0, then write DATA (`0x2_0004`).

## Build

The core is configured RV32E (16 registers) with hardware multiply, divide and
compressed instructions, so the toolchain flags must match exactly:

```bash
ARCH="-march=rv32emc -mabi=ilp32e"
LIBGCC=$(riscv64-unknown-elf-gcc $ARCH -print-libgcc-file-name)

riscv64-unknown-elf-gcc $ARCH -Os -nostdlib -ffreestanding -nostartfiles \
  -T link.ld primes.c "$LIBGCC" -o primes.elf
riscv64-unknown-elf-objcopy -O binary primes.elf primes.bin
```

`$LIBGCC` must come **after** the source file — the linker resolves
left to right.

Convert to scan-loadable hex (32-bit little-endian words):

```bash
python3 -c "
d=open('primes.bin','rb').read(); d+=b'\x00'*((-len(d))%4)
print('\n'.join('%08x'%int.from_bytes(d[i:i+4],'little') for i in range(0,len(d),4)))" > primes.hex
```

**Wrong flags produce illegal instructions on silicon.** Using `-march=rv32imc`
or `-mabi=ilp32` assumes 32 registers, which this core does not have.

## Run in simulation

`tb/tb_demo.sv` scan-loads a program (from the matching `tb/g_*_prog.svh`),
configures the FSM to RUN, and checks peripheral pin activity.

**Note:** the verification environment has not yet been updated for the 1 KB
memory configuration. See `VERIFICATION.md`.
