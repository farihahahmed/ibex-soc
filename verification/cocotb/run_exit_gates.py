#!/usr/bin/env python3
"""Run Pico SoC tapeout gates one-by-one. Ctrl-C safe."""
import os, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
env = os.environ.copy()
env["PYTHONPATH"] = str(HERE) + ":" + env.get("PYTHONPATH", "")

GATES = [
    ("dmem directed", ["make", "dmem"]),
    ("block regress", ["make", "-C", "block", "block-regress"]),
    ("coverage merge", ["python3", "merge_coverage.py"]),
]

def run(name, cmd):
    print(f"\n===== GATE: {name} =====")
    print(" ", " ".join(cmd))
    r = subprocess.run(cmd, cwd=HERE, env=env)
    if r.returncode != 0:
        print(f"FAIL: {name}")
        return False
    print(f"PASS: {name}")
    return True

def main():
    fails = []
    for name, cmd in GATES:
        if not run(name, cmd):
            fails.append(name)
    print("\n===== SUMMARY =====")
    if fails:
        print("FAILED:", ", ".join(fails))
        return 1
    print("ALL GATES PASS")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
