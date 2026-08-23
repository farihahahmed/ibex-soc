#!/usr/bin/env python3
"""Run formal BMC on test_fsm (Yosys + yosys-smtbmc/yices)."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SMT2 = ROOT / "formal_test_fsm.smt2"
RTL = ROOT / "rtl" / "test_fsm.sv"
FORMAL = ROOT / "verification" / "formal" / "test_fsm_formal.sv"

def run(cmd, **kw):
    print("+", " ".join(cmd))
    r = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, **kw)
    if r.stdout:
        print(r.stdout[-2000:] if len(r.stdout) > 2000 else r.stdout)
    if r.stderr:
        print(r.stderr[-1500:] if len(r.stderr) > 1500 else r.stderr)
    return r.returncode

def main():
    if not RTL.exists() or not FORMAL.exists():
        print("Missing RTL or formal SV", file=sys.stderr)
        return 1

    yosys_script = f"""
read_verilog -sv {RTL} {FORMAL}
prep -top test_fsm_formal
async2sync
dffunmap
write_smt2 -wires {SMT2}
"""
    rc = run(["yosys", "-p", yosys_script])
    if rc != 0 or not SMT2.exists() or SMT2.stat().st_size == 0:
        print("Yosys failed or empty SMT2", file=sys.stderr)
        return 1

    rc = run(["yosys-smtbmc", "-s", "yices", "-t", "20", str(SMT2)])
    if rc != 0:
        print("BMC FAILED", file=sys.stderr)
        return 1
    print("=== formal test_fsm: PASSED ===")
    return 0

if __name__ == "__main__":
    sys.exit(main())
