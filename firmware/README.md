# Firmware

RISC-V programs for the SoC. Compiled with the RV32IMC toolchain, converted to
scan-loadable hex words, and loaded over the scan chain in simulation.

| File | What it does |
|------|--------------|
| `piezo_tune.c` | Plays "Happy Birthday" on a GPIO output pin by toggling it at each note's frequency (square-wave tone for a piezo speaker). |
| `link.ld` | Linker script: code at 0x80, imem region. |
| `piezo_tune.hex` | Compiled program as 32-bit words (one per line). |

## Build

```bash
riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -nostdlib -ffreestanding \
  -nostartfiles -Wl,-Ttext=0x80 -T link.ld piezo_tune.c -o piezo_tune.elf
riscv64-unknown-elf-objcopy -O binary piezo_tune.elf piezo_tune.bin
# then split into 32-bit little-endian words -> piezo_tune.hex
```

Verified by `tb/tb_piezo.sv`: scan-loads the program, runs it, and confirms the
GPIO pin oscillates (tone playing).
