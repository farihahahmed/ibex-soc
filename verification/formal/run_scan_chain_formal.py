#!/usr/bin/env python3
"""Formal BMC on scan_chain load/tgt decode."""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SMT2 = ROOT / "formal_scan_chain.smt2"
RTL = ROOT / "rtl" / "scan_chain.sv"
FORMAL = ROOT / "verification" / "formal" / "scan_chain_formal.sv"
SOLVER = os.environ.get("SMT_SOLVER", "yices")

def run(cmd):
    print("+", " ".join(str(c) for c in cmd))
    r = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    out = (r.stdout or "") + (r.stderr or "")
    if len(out) > 2500:
        print(out[-2500:])
    else:
        print(out)
    return r.returncode

def main():
    script = f"""
read_verilog -sv {RTL} {FORMAL}
prep -top scan_chain_formal
async2sync
dffunmap
write_smt2 -wires {SMT2}
"""
    rc = run(["yosys", "-p", script])
    if rc != 0 or not SMT2.exists() or SMT2.stat().st_size == 0:
        print("Yosys failed", file=sys.stderr)
        return 1
    rc = run(["yosys-smtbmc", "-s", SOLVER, "-t", "20", str(SMT2)])
    if rc != 0:
        print("BMC FAILED", file=sys.stderr)
        return 1
    print("=== formal scan_chain: PASSED ===")
    return 0

if __name__ == "__main__":
    sys.exit(main())
