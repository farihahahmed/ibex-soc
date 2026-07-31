# Firmware

RISC-V demo programs for the SoC, matching the three Columbia demo options.
Compiled with the RV32IMC toolchain, converted to scan-loadable hex words,
and loaded over the scan chain. Each fits the 512 B instruction memory.

| File | Demo | Drives | Verified |
|------|------|--------|----------|
| `piezo_tune.c` | "Happy Birthday" tone | GPIO out[0] (piezo) | gpio toggles 1422× |
| `primes.c` | Prime numbers streamed to a PC terminal | UART tx | uart toggles 220× |
| `game.c` | Dodge game on an SPI LCD | SPI sclk/mosi | spi toggles 13104× |

`link.ld` places code at 0x80 in the instruction memory.

## Build

```bash
riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -nostdlib -ffreestanding \
  -nostartfiles -Wl,-Ttext=0x80 -T link.ld primes.c -o primes.elf
riscv64-unknown-elf-objcopy -O binary primes.elf primes.bin
# split into 32-bit little-endian words -> primes.hex
```

## Run in simulation

`tb/tb_demo.sv` is a generic runner: scan-loads a program, configures the FSM to
RUN, and counts peripheral pin activity. Select the program with defines:

```bash
verilator ... -DNWORDS=26 -DPROGFILE='"g_primes_prog.svh"' -DPROGNAME='"primes"' ...
```

All three demos are verified on the current design (narrow memory, scan-configured FSM).
