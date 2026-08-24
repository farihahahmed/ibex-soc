**PicoRV32 SoC on GF180MCU**

A compact RISC-V system-on-chip targeting a **1 mm²** die on the open **GlobalFoundries 180 nm (GF180MCU)** process. The design is implemented entirely with open-source tools, from RTL through place-and-route and signoff.

|                 |                                                   |
| --------------- | ------------------------------------------------- |
| **ISA**         | RV32IMC (PicoRV32)                                |
| **Memory**      | 256 B instruction + 64 B data (narrow 8-bit SRAM) |
| **Bus**         | AHB-Lite + APB                                    |
| **Peripherals** | GPIO, UART, SPI                                   |
| **Bring-up**    | Scan chain and clock-gating FSM                   |
| **Process**     | GF180MCU, open PDK                                |
| **Die**         | 1000 × 1000 µm                                    |

> The repository name `ibex-soc` is historical. An earlier Ibex-based floorplan could not meet the area constraint; the core was replaced with synthesizable PicoRV32 so standard cells and SRAMs could share the die.

---

**Signoff status**

Artifact: `gds/chip_top_full.gds`

| Check   | Result                       |
| ------- | ---------------------------- |
| DRC     | Clean (`gds/DRC_RESULT.txt`) |
| LVS     | Match (`gds/lvs_report.rpt`) |
| Antenna | Clean                        |
| Timing  | See `TIMING_REPORT.md`       |
| Area    | See `AREA_REPORT.md`         |

A documented Metal3/PDN post-route fix for the GF180 SRAM macros is applied via `gds/heal_metal3.tcl`.

---

**Repository layout**

| Path            | Description                                                                |
| --------------- | -------------------------------------------------------------------------- |
| `rtl/`          | Design RTL (`chip_top_full` and blocks)                                    |
| `firmware/`     | Demo software (primes, piezo, game)                                        |
| `verification/` | Verification environment (cocotb / pyuvm, block tests, formal, gate-level) |
| `openlane/`     | Physical-design configuration                                              |
| `gds/`          | GDS and signoff reports                                                    |
| `docs/`         | Figures and written review material                                        |
| `archive/`      | Historical design snapshots (not part of the live flow)                    |

Supporting notes: `memory_map.md` · `PINOUT.md` · `VERIFICATION.md`

---

**Verification**

From the cocotb working directory:

```
cd verification/cocotb
export PYTHONPATH="$(pwd):${PYTHONPATH}"
./run_block_regress.sh
./run_all_verify.sh
```

`./run_all_verify.sh` is the project exit gate and must complete with exit code 0. Further detail is in `VERIFICATION.md` and `verification/docs/`.

---

**Tooling**

- Simulation: Icarus Verilog, cocotb, pyuvm
- Synthesis and P&R: Yosys, LibreLane / OpenROAD
- Signoff: Magic, Netgen
- Optional core packaging: FuseSoC (`pico_soc.core`)

---

**License**

Project configuration and Chipathon metadata: see `info.yaml`. Individual third-party cores (e.g. PicoRV32) retain their upstream licenses.
