# Ibex SoC on GF180MCU

A from-scratch RISC-V System-on-Chip built on the open-source **GF180MCU (180nm)** process, using the Ibex RV32IMC core. Front-end flow: RTL → simulation → synthesized netlist.

**Status: complete front-end flow.** The full SoC boots, runs a program from on-chip memory, and drives all peripherals — verified in both RTL and gate-level simulation. It synthesizes to **0.911 mm²**, fitting the 1 mm² die target.

## Contents

| Path | What's inside |
|------|---------------|
| [`progress_tracker.md`](progress_tracker.md) | Live status of every block, phase by phase |
| [`AREA_REPORT.md`](AREA_REPORT.md) | Synthesized area breakdown (0.911 mm², fits 1 mm²) |
| [`TIMING_REPORT.md`](TIMING_REPORT.md) | Static timing: setup MET, ~147 MHz Fmax |
| [`memory_map.md`](memory_map.md) | Address map + narrow-memory notes |
| [`detailed_schematic_review.md`](detailed_schematic_review.md) | Detailed design walkthrough and architecture notes |
| `chip_top.nl.v` | Deliverable gate-level netlist |
| `rtl/` | Synthesizable design files (`.sv`) |
| `tb/` | Self-checking testbenches |

## Quick specs

| | |
|---|---|
| CPU | Ibex RV32IMC |
| Memory | Narrow 8-bit: 512 B instruction (1× 512×8) + 64 B data (1× 64×8), byte gather/scatter |
| Peripherals | GPIO, UART, SPI |
| Bus | Two-tier AHB-Lite + APB |
| Process | GF180MCU (180nm) |
| Die area | 0.911 mm² with pads / 0.761 mm² without — fits 1 mm² |
| Max frequency | ~147 MHz (setup MET at target clock) |

## Key result: fitting 1 mm²

A conventional 32-bit memory needs four 8-bit SRAM macros per bank and does not fit
the 1 mm² die. This design uses **narrow 8-bit memories**: a single SRAM macro
fronted by a byte gather/scatter unit that makes it look like a normal 32-bit
memory to the CPU (reads stream 4 bytes and assemble a word; writes split into
byte-enabled byte-writes). The data memory adds AHB wait-states for its multi-cycle
access. This is the key area lever — see [`AREA_REPORT.md`](AREA_REPORT.md).

## Verification

- **RTL simulation:** full SoC scan-loads a program, boots, and drives GPIO (0xA5) + UART (0x41) + SPI (0xB7). Every block has a self-checking testbench.
- **Gate-level simulation:** the synthesized netlist (`chip_top.nl.v`) reproduces the same peripheral outputs — RTL-vs-netlist equivalence confirmed.
- **Timing:** OpenSTA reports setup MET with +113 ns worst-case slack.

## Running a testbench

```bash
iverilog -g2012 -o sim -s tb_dmem_narrow \
  tb/tb_dmem_narrow.sv rtl/dmem_narrow_top.sv rtl/dmem_narrow.sv \
  /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram__sram64x8m8wm1.v
vvp sim
```

Full-SoC integration and gate-level testbenches build with Verilator / iverilog against the Ibex source list; see `tb/tb_chip_full.sv` (RTL) and `tb/tb_chip_gate.sv` (gate-level).
