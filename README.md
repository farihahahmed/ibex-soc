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
| **Clock** | 32 ns / **31 MHz** |
| **Bus** | AHB-Lite + APB |
| **Peripherals** | GPIO, UART, SPI |
| **Bring-up** | Scan chain and clock-gating FSM |
| **Process** | GF180MCU, open PDK |
| **Die** | 1100 × 1100 µm (A45 slot allows 1110 × 1110) |
| **Utilization** | 76.3% |

### **Signoff status**

Artifact: `gds/chip_top_full.gds` (unmodified LibreLane output)
Run: `openlane/chip_top_full/runs/RUN_2026-08-25_09-23-07` (tag `v2-signoff`)

| Check | Result |
| --- | --- |
| LVS | Match uniquely (`gds/lvs_report.rpt`) |
| Antenna | 0 violations |
| Timing | Clean, all 9 corners — setup +10.01 ns, hold +0.087 ns |
| DRC | 4 × M3.1 — see below |
| Area | `AREA_REPORT.md` |

**Known DRC finding.** The four Magic DRC violations (M3.1, Metal3 width) are
not produced by this design. They originate in the GF180 SRAM macro LEFs:
every `gf180mcu_fd_ip_sram__sram*x8m8wm1` LEF contains a 0.110 µm tall Metal3
port rectangle on the **VSS** pin, against an M3.1 minimum of 0.56 µm. Both
macro instances flag it at identical relative offsets, and our LEF copies are
md5-identical to the PDK's. Full investigation and evidence:
`docs/A45_m3_drc_report.txt`. Raised with the organizers; awaiting guidance on
whether to waive.

### **Repo layout**

| Path | Description |
| --- | --- |
| `rtl/` | Design RTL (`chip_top_full` and blocks) |
| `firmware/` | Demo software (primes, piezo, game) |
| `verification/` | Verification environment (cocotb / pyuvm, block tests, gate-level) |
| `openlane/` | Physical-design configuration and runs |
| `gds/` | GDS and signoff reports |
| `docs/` | Investigation notes and review material |
| `archive/` | Historical design snapshots (not part of the live flow) |

Supporting notes: `memory_map.md` · `PINOUT.md` · `AREA_REPORT.md` ·
`TIMING_REPORT.md` · `VERIFICATION.md`

### **Verification**

```
cd verification/cocotb
export PYTHONPATH="$(pwd):${PYTHONPATH}"
./run_block_regress.sh
./run_all_verify.sh
```

`./run_all_verify.sh` is the project exit gate and must complete with exit
code 0. Detail in `VERIFICATION.md` and `verification/docs/`.

**Current status:** the exit gate passes on the current design —
12 tests, 0 failures, exit code 0 (2026-08-25).

### **Tooling**

- Simulation: Icarus Verilog, cocotb, pyuvm
- Synthesis and P&R: Yosys, LibreLane / OpenROAD
- Signoff: Magic, Netgen
- Optional core packaging: FuseSoC (`pico_soc.core`)

### **Design history**

The repository was originally named `ibex-soc`. An early Ibex-based floorplan
could not meet the area constraint — its hardened CPU macro alone was
0.743 mm² and could not tile with the SRAMs — so the core was replaced with
synthesized PicoRV32. `AREA_REPORT.md` covers this in full.

### **License**

Project configuration and Chipathon metadata: see `info.yaml`. Third-party
cores (e.g. PicoRV32) retain their upstream licenses.
