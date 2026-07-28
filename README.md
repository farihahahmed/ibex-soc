# Ibex SoC on GF180MCU

A from-scratch RISC-V System-on-Chip built on the open-source **GF180MCU (180nm)** process, using the Ibex RV32IMC core. Front-end flow: RTL → simulation → synthesized netlist.

## Contents

| Path | What's inside |
|------|---------------|
| [`progress_tracker.md`](progress_tracker.md) | Live status of every block, phase by phase |
| [`detailed_schematic_review.md`](detailed_schematic_review.md) | Detailed design walkthrough and architecture notes |
| `rtl/` | Synthesizable design files (`.sv`) |
| `tb/` | Self-checking testbenches |

## Quick specs

| | |
|---|---|
| CPU | Ibex RV32IMC |
| Memory | 4 KB SRAM (2 KB instruction / 2 KB data) |
| Peripherals | GPIO, UART, SPI |
| Process | GF180MCU (180nm) |

## Running a testbench

```bash
iverilog -g2012 -o sim -s tb_sram_bank \
  tb/tb_sram_bank.sv rtl/sram_bank_2k.sv \
  /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram__sram512x8m8wm1.v
vvp sim
```
