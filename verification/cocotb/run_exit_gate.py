#!/usr/bin/env python3
"""Pico SoC verification exit gate (block MDV → pyuvm → coverage)."""
import os
import subprocess
import sys

ROOT = "/foss/designs/pico_soc/verification/cocotb"
os.environ["PYTHONPATH"] = ROOT + ":" + os.environ.get("PYTHONPATH", "")

def run(cmd, cwd=ROOT):
    print(f"\n>>> {' '.join(cmd)}  (cwd={cwd})")
    r = subprocess.run(cmd, cwd=cwd)
    if r.returncode != 0:
        print(f"FAIL: {cmd} rc={r.returncode}")
        sys.exit(r.returncode)
    print("OK")

def main():
    print("===== 1/3 BLOCK MDV =====")
    run(["bash", "run_block_regress.sh"])

    print("\n===== 2/3 CHIP pyuvm =====")
    run(["make", "pyuvm-regress"])

    print("\n===== 3/3 COVERAGE MERGE =====")
    if os.path.isfile(os.path.join(ROOT, "merge_coverage.py")):
        run(["python3", "merge_coverage.py"])
    else:
        print("(no merge_coverage.py – skip)")

    print("\n===== EXIT GATE: ALL PASS =====")

if __name__ == "__main__":
    main()
