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
| **Bring-up** | Scan chain and clock-gating FSM |
| **Process** | GF180MCU, open PDK |
| **Die** | 1100 × 1100 µm (A45 slot allows 1110 × 1110) |
| **Utilization** | 82.0% |

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
| Area / detail | `AREA_REPORT.md`, `docs/BACKEND_REPORT.md` |

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

Supporting notes: `memory_map.md` · `PINOUT.md` · `AREA_REPORT.md` ·
`TIMING_REPORT.md` · `VERIFICATION.md` · `docs/BACKEND_REPORT.md`

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
synthesized PicoRV32. `AREA_REPORT.md` covers this in full.

The CPU clock gate was later changed from a combinational AND
(`clk & run_gate_q`) to a PDK integrated clock-gating cell (`icgtp_1`,
matching `clk_gen.sv`). This resolved a persistent Metal3 antenna violation,
high-fanout slew, and a detailed-routing failure, all rooted in the weak-driver
gated-clock net. The gate is functionally verified equivalent (formal + full
cocotb regression).

### **License**

Project configuration and Chipathon metadata: see `info.yaml`. Third-party
cores (e.g. PicoRV32) retain their upstream licenses.
