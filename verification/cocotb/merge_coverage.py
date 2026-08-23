#!/usr/bin/env python3
"""Accumulate gpio_value bins across many random seeds (Phase 4 merge)."""
import os, re, subprocess, sys, json
from pathlib import Path

SEEDS = list(range(42, 72))
OUT = Path("coverage_merge.json")
bins = {}

for s in SEEDS:
    env = os.environ.copy()
    env["RANDOM_SEED"] = str(s)
    env["PYTHONPATH"] = os.getcwd() + ":" + env.get("PYTHONPATH", "")
    r = subprocess.run(
        ["make", "COCOTB_TEST_MODULES=test_pyuvm_random"],
        env=env, capture_output=True, text=True
    )
    text = r.stdout + r.stderr
    if r.returncode != 0:
        print(f"seed {s} FAILED")
        print(text[-600:])
        sys.exit(1)
    m = re.search(r"final GPIO=0x([0-9a-f]+)", text)
    if not m:
        print(f"seed {s}: no GPIO parse")
        print(text[-400:])
        sys.exit(1)
    val = int(m.group(1), 16)
    bins[val] = bins.get(val, 0) + 1
    print(f"seed {s}: 0x{val:02x}  unique={len(bins)}")

report = {
    "seeds": SEEDS,
    "unique_bins": len(bins),
    "hits": {str(k): v for k, v in sorted(bins.items())},
    "goal_unique": 5,
    "pass": len(bins) >= 5,
}
OUT.write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
print("PASS" if report["pass"] else "FAIL")
sys.exit(0 if report["pass"] else 1)
