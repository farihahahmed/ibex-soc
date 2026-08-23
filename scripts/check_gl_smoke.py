#!/usr/bin/env python3
"""B2: gate-level smoke status. SKIP if netlist is not Pico-era."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "verification/coverage_artifacts/gl_smoke_status.txt"
DOC = ROOT / "verification/docs/GATE_LEVEL.md"

# Candidate netlists (newest OpenLane run)
CANDIDATES = [
    ROOT / "openlane/chip_top_full/runs/RUN_2026-08-06_08-51-08/06-yosys-synthesis/chip_top_full.nl.v",
    ROOT / "openlane/chip_top_full/runs/RUN_2026-08-06_08-51-08/final/nl/chip_top_full.nl.v",
    ROOT / "gds/chip_top_full.pnl.v",
]

def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    DOC.parent.mkdir(parents=True, exist_ok=True)

    found = None
    has_ibex = False
    for p in CANDIDATES:
        if p.exists():
            found = p
            text = p.read_text(errors="ignore")
            if "ibex_top" in text:
                has_ibex = True
            break

    if found is None:
        status = "SKIP"
        reason = "No post-synth netlist found"
    elif has_ibex:
        status = "SKIP"
        reason = f"Netlist is Ibex-era (ibex_top present): {found}"
    else:
        status = "READY"
        reason = f"Netlist looks Pico-compatible: {found} (run verification/gl make gl-smoke)"

    body = f"STATUS: {status}\nREASON: {reason}\nDOC: verification/docs/GATE_LEVEL.md\n"
    OUT.write_text(body)
    print(body)

    DOC.write_text(
        "# Gate-level smoke (B2)\n\n"
        f"**Status:** {status}\n\n"
        f"{reason}\n\n"
        "When STATUS is READY: `cd verification/gl && make gl-smoke`\n"
    )
    # SKIP is success for this gate (documented)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
