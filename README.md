# PicoRV32 SoC on GF180MCU — 1 mm²

RISC-V **RV32IMC** SoC (PicoRV32) on open **GF180MCU**, open-source flow
(Icarus · Yosys · LibreLane/OpenROAD · Magic · Netgen).

> Repo name `ibex-soc` is historical: Ibex's hardened macro did not tile with
> the SRAMs inside 1 mm², so the CPU was swapped to synthesizable PicoRV32.

## Signoff (current GDS: `gds/chip_top_full.gds`)

| Check | Result |
|-------|--------|
| DRC | 0 errors (Magic; see `gds/DRC_RESULT.txt`) |
| LVS | Match (`gds/lvs_report.rpt`) |
| Antenna | Passed |
| Die | 1000 × 1000 µm |

Metal3 SRAM/PDN heal: `gds/heal_metal3.tcl`.

## Design snapshot

| | |
|---|---|
| CPU | PicoRV32 RV32IMC |
| Memory | Narrow 8-bit: 256 B IMEM + 64 B DMEM |
| Bus | AHB-Lite + APB |
| IO | GPIO, UART, SPI |
| Bring-up | Scan chain + clock-gating FSM |

Details: [memory_map.md](memory_map.md) · [PINOUT.md](PINOUT.md) ·
[AREA_REPORT.md](AREA_REPORT.md) · [TIMING_REPORT.md](TIMING_REPORT.md)

## Repo layout

| Path | Contents |
|------|----------|
| `rtl/` | Live RTL (`chip_top_full`) |
| `firmware/` | Demo programs (primes, piezo, game) |
| `verification/` | Canonical verification (cocotb/pyuvm, block MDV, formal, GL) |
| `verification/legacy_sv/` | Older directed SV goldens |
| `verification/docs/` | How to run, gates, coverage, MDV |
| `openlane/` | PD config |
| `gds/` | GDS + DRC/LVS reports |
| `docs/images/` | Layout screenshots |
| `archive/` | Historical RTL (not live) |

## How to verify

    cd verification/cocotb
    export PYTHONPATH="$(pwd):${PYTHONPATH}"
    ./run_block_regress.sh
    ./run_all_verify.sh

Full story: [VERIFICATION.md](VERIFICATION.md)

## Review write-up

[docs/detailed_schematic_review.md](docs/detailed_schematic_review.md)
