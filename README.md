### PicoRV32 SoC on GF180MCU

[![verify](https://github.com/farihahahmed/pico-soc/actions/workflows/verify.yml/badge.svg)](https://github.com/farihahahmed/pico-soc/actions/workflows/verify.yml)

A compact RISC-V system-on-chip on the open **GlobalFoundries 180 nm (GF180MCU)**
process, implemented entirely with open-source tools from RTL through
place-and-route and signoff. IEEE Chipathon 2026 submission (project A45).

| Spec | Value |
| --- | --- |
| **CPU** | PicoRV32 |
| **ISA** | RV32E + M + C (16 registers, hardware multiply and divide, compressed) |
| **Memory** | 512 B instruction + 512 B data = **1 KB** (narrow 8-bit SRAM) |
| **Clock** | 40 ns input (**25 MHz**); on-chip ÷2 to a **12.5 MHz** system/CPU domain |
| **Clock gating** | CPU clock gated by an integrated clock-gating cell (ICG), FSM-controlled |
| **Bus** | AHB-Lite + APB |
| **Peripherals** | GPIO, UART, SPI |
| **Accelerator** | PCPI custom co-processor (CRC32, popcount, bit-reverse, signed MAC) |
| **Bring-up** | Scan chain and clock-gating FSM |
| **Process** | GF180MCU, open PDK |
| **Die** | 1100 × 1100 µm (A45 slot allows 1110 × 1110) |
| **Utilization** | 82.0% |


### **PCPI custom accelerator**

Seven single-cycle custom instructions on PicoRV32's PCPI interface (custom-0
opcode `0x0B`) — each does in one cycle what would otherwise take a software
loop. Measured on the gate-level SoC:

| Workload | Software | Custom | Gain |
| --- | ---: | ---: | ---: |
| CRC32 (64 bytes) | 39,143 cyc | 3,785 cyc | **10.34× faster** |
| FIR noise ripple | 30 | 6 | **5× cleaner** |

Full methodology and reproduction steps: [PCPI benchmarks](docs/PCPI_BENCHMARKS.md).

**Real-world applications**

#### Digital signal processing — the FIR filter demo

The signed multiply-accumulate instructions (`mac` / `macrd` / `macclr`) are the
core of digital signal processing: filtering, audio, motor control, sensor
fusion. The `fir_demo` firmware shows it end to end — a 5-tap moving-average
filter (taps 1-2-4-2-1) runs over a noisy ±100 square wave and **cuts the noise
ripple 5×, from 30 down to 6**, while preserving the signal, printing raw vs
filtered pairs live over UART. Every tap is one `mac` instruction instead of a
multiply-then-add software sequence.

#### Data integrity — CRC32

`crc32.b` / `crc32.w` checksum a UART or SPI message to catch corruption in
transit — the same check used by Ethernet and zip files. One instruction
replaces a 1 KB lookup table that wouldn't fit in this chip's 512 B of data
memory (reflected polynomial `0xEDB88320`, zlib/Ethernet compatible). This is
the **10.34× speedup** in the table above.

#### Bit manipulation — popcount & bit-reverse

`popcnt` and `brev` do in one cycle what is a software loop otherwise — counting
set bits and reversing bit order. Used in error-correction codes, hashing, FFT
reordering, and protocol parsing.

The accelerator lives entirely inside the CPU — no bus, no memory, **no pins**;
any unclaimed encoding traps. You observe its results through UART or GPIO.

| funct3 | Instruction | Operation |
| --- | --- | --- |
| `000` | `crc32.b` | Fold one byte (`rs2[7:0]`) into the running CRC32 in `rs1` |
| `001` | `crc32.w` | Fold a word (`rs2[31:0]`) into the CRC32 in `rs1` |
| `010` | `popcnt` | Count set bits in `rs1` |
| `011` | `brev` | Bit-reverse `rs1` |
| `100` | `mac` | `acc += signed(rs1[15:0]) * signed(rs2[15:0])`; return `acc` |
| `101` | `macrd` | Read the MAC accumulator (no change) |
| `110` | `macclr` | Clear the MAC accumulator |

Verified by directed cocotb tests (`chip crc32`, `chip pcpi`, `pcpi cycles`,
FIR) and 7 formal properties: an unclaimed `funct3` never raises `pcpi_ready`,
`pcpi_wr == pcpi_ready`, single-cycle completion, `pcpi_wait` stays low.

### **Pinout (22 pins: 20 signal + 2 power)**

Verified against the signed-off netlist (`gds/chip_top_full.pnl.v`). Full detail
in `docs/PINOUT.md`.

| Group | Pins | Dir | Purpose |
| --- | --- | --- | --- |
| Clock | `clk`, `clk_int` | in | 25 MHz input; `clk_int` picks internal vs external source |
| Reset | `rst_n` | in | Active-low reset |
| Scan | `scan_in`, `scan_shift`, `scan_load`, `scan_i0o1` | in | Program load, config, and control via scan chain |
| Scan | `scan_out` | out | Scan readback |
| GPIO | `gpio_in[1:0]` | in | 2 buttons |
| GPIO | `gpio_out[3:0]` | out | 4 LEDs (or piezo) |
| UART | `uart_rx`, `uart_tx` | in / out | Serial console |
| SPI | `spi_miso` | in | SPI data in (e.g. sensor) |
| SPI | `spi_sclk`, `spi_mosi`, `spi_cs_n` | out | SPI master (e.g. LCD) |
| Power | `VDD`, `VSS` | — | 5.0 V supply |

Bring-up goes through the **scan chain** rather than dedicated pins: FSM
start/mode, clock config, program load, and status/state readback are all
shifted in and out over the existing scan interface. Giving each of those four
functions its own pin would have cost 4 extra pins; folding them into the scan
chain keeps the design at 22.

### **Signoff status**

Artifact: `gds/chip_top_full.gds` (unmodified LibreLane output)
Run: `openlane/chip_top_full/runs/RUN_2026-08-28_09-52-02`

| Check | Result |
| --- | --- |
| LVS | Match uniquely (`gds/lvs_report.rpt`) |
| Antenna | **0 violations** |
| Timing | Clean, all 9 corners — setup +4.17 ns, hold +0.33 ns |
| DRC | 4 × M3.1 — SRAM-macro, waived (see below) |
| IR drop | 0.04% worst (2.05 mV) |
| Power | 48.3 mW (nom_tt) |
| Area / detail | `docs/AREA_REPORT.md`, `docs/BACKEND_REPORT.md` |

**CPU clock fmax:** 13.2 MHz worst corner (ss_125C_4v50) vs 12.5 MHz operating.

**Known DRC finding (waived).** The four Magic DRC violations (M3.1, Metal3
width) are not produced by this design. They originate in the GF180 SRAM macro
LEFs: every `gf180mcu_fd_ip_sram__sram*x8m8wm1` LEF contains a 0.110 µm tall
Metal3 port rectangle on the **VSS** pin, against an M3.1 minimum of 0.56 µm.
Both macro instances flag it at identical relative offsets, and our LEF copies
are md5-identical to the PDK's. They are macro-internal, not routing-induced,
so the signoff artifact is the unmodified flow output. Evidence:
`docs/A45_m3_drc_report.txt`; waiver summary: `gds/DRC_RESULT.txt`.

### **Repo layout**

| Path | Description |
| --- | --- |
| `rtl/` | Design RTL (`chip_top_full` and blocks) |
| `firmware/` | Demo software (primes, piezo, game) |
| `verification/` | Verification environment (cocotb / pyuvm, block tests, formal, gate-level) |
| `openlane/` | Physical-design configuration and runs |
| `gds/` | GDS and signoff reports |
| `docs/` | Investigation notes and review material |

### **Documentation**

| Doc | Covers |
| --- | --- |
| [Pinout](docs/PINOUT.md) | All 22 pins — direction and purpose |
| [Memory map](docs/memory_map.md) | Address decode, registers, boot/stack |
| [Area report](docs/AREA_REPORT.md) | Placed area, utilization, cell breakdown |
| [Timing report](docs/TIMING_REPORT.md) | STA across all 9 PVT corners |
| [Back-end signoff](docs/BACKEND_REPORT.md) | Antenna, LVS, DRC, IR-drop, power |
| [PCPI benchmarks](docs/PCPI_BENCHMARKS.md) | Measured CRC32 10.3× and FIR 5× results |
| [Verification](VERIFICATION.md) | Test strategy, single gate, formal |
| [Schematic review](docs/detailed_schematic_review.md) | Block-by-block design review |

### **Verification**

```
cd verification/cocotb
export PYTHONPATH="$(pwd):${PYTHONPATH}"
./run_all_verify.sh
```

`./run_all_verify.sh` is the project exit gate and must complete with exit
code 0. It is a single honest gate: no excluded tests, no allowed-to-fail
legs. Detail in `VERIFICATION.md` and `verification/docs/`.

**Current status (2026-08-28):** exit gate passes on the current design —
**49 suites, 0 failures, exit code 0**. FSM state/arc coverage 40/40 (100%);
stress-path functional coverage closed. Verified against the post-ICG RTL.

**Formal:** bounded model checking via `verification/formal/run_formal.py` —
**42 properties across 7 targets** (FSM, lockout, PCPI, gather, bridge, shim,
bus fabric), plus dedicated scan-chain and FSM runners. All green in CI.

### **Tooling**

- Simulation: Icarus Verilog, cocotb, pyuvm
- Formal: Yosys + yosys-smtbmc (yices)
- Synthesis and P&R: Yosys, LibreLane / OpenROAD
- Signoff: Magic, Netgen
- Optional core packaging: FuseSoC (`pico_soc.core`)

### **Design history**

The repository was originally named `ibex-soc`. An early Ibex-based floorplan
could not meet the area constraint — its hardened CPU macro alone was
0.743 mm² and could not tile with the SRAMs — so the core was replaced with
synthesized PicoRV32. `docs/AREA_REPORT.md` covers this in full.

The CPU clock gate was later changed from a combinational AND
(`clk & run_gate_q`) to a PDK integrated clock-gating cell (`icgtp_1`,
matching `clk_gen.sv`). This resolved a persistent Metal3 antenna violation,
high-fanout slew, and a detailed-routing failure, all rooted in the weak-driver
gated-clock net. The gate is functionally verified equivalent (formal + full
cocotb regression).

### **License**

Project configuration and Chipathon metadata: see `info.yaml`. Third-party
cores (e.g. PicoRV32) retain their upstream licenses.
