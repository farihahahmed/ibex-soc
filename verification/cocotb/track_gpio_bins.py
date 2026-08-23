#!/usr/bin/env python3
"""Run many random seeds and report unique GPIO bins hit."""
import os, re, subprocess, sys

seeds = list(range(42, 72))  # 30 seeds
bins = set()
for s in seeds:
    env = os.environ.copy()
    env["RANDOM_SEED"] = str(s)
    env["PYTHONPATH"] = os.getcwd() + ":" + env.get("PYTHONPATH", "")
    r = subprocess.run(
        ["make", "COCOTB_TEST_MODULES=test_pyuvm_random"],
        env=env, capture_output=True, text=True
    )
    text = r.stdout + r.stderr
    m = re.search(r"final GPIO=0x([0-9a-f]+)|target GPIO=0x([0-9a-f]+)", text)
    if m:
        val = int(m.group(1) or m.group(2), 16)
        bins.add(val)
        status = "OK" if r.returncode == 0 else "FAIL"
        print(f"seed {s}: GPIO 0x{val:02x}  unique={len(bins)}  {status}")
        if r.returncode != 0:
            print(text[-800:])
            sys.exit(1)
    else:
        print(f"seed {s}: parse failed rc={r.returncode}")
        print(text[-800:])
        sys.exit(1)

print(f"\nUnique GPIO bins: {len(bins)} -> {sorted(bins)}")
if len(bins) < 5:
    print("FAIL: need >= 5 distinct bins")
    sys.exit(1)
print("PASS: exit criterion 4 met (>= 5 distinct gpio_value bins)")
