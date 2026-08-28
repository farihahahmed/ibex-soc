#!/usr/bin/env python3
"""Enforce a line-coverage floor on our own RTL.

Reads the authoritative lcov artifact (verification/coverage/coverage.info) and
applies the same exclusions the docs use (picorv32 core + GF180/SRAM cell
models are third-party IP, not our RTL). Exits non-zero if coverage is below
the floor, so a regression fails CI. Coverage is enforced, not just reported.

Usage: check_coverage_floor.py [--floor N]   (default 85, or COVERAGE_FLOOR env)
"""
import os
import sys
from pathlib import Path
from collections import defaultdict

INFO = Path(__file__).resolve().parents[1] / "coverage" / "coverage.info"
SKIP = ("picorv32", "gf180", "sram")   # third-party IP, excluded from "our RTL"

floor = 85.0
for i, a in enumerate(sys.argv):
    if a == "--floor" and i + 1 < len(sys.argv):
        floor = float(sys.argv[i + 1])
if os.environ.get("COVERAGE_FLOOR"):
    floor = float(os.environ["COVERAGE_FLOOR"])

if not INFO.is_file():
    print(f"MISSING {INFO} — run the coverage build first (make coverage-run)")
    sys.exit(1)

per = defaultdict(lambda: [0, 0])   # file -> [hit, found]
cur = None
for line in INFO.read_text().splitlines():
    if line.startswith("SF:"):
        cur = line[3:].split("/")[-1]
    elif line.startswith("DA:") and cur:
        num, cnt = line[3:].split(",")[:2]
        per[cur][1] += 1
        if int(cnt) > 0:
            per[cur][0] += 1

own = {f: hf for f, hf in per.items() if not any(s in f.lower() for s in SKIP)}
hit = sum(h for h, _ in own.values())
found = sum(f for _, f in own.values())
pct = 100.0 * hit / max(found, 1)

print(f"Line coverage of our own RTL (picorv32/gf180/sram excluded):")
for f, (h, t) in sorted(own.items()):
    print(f"  {f:28} {h:4}/{t:4}  {100.0*h/max(t,1):5.1f}%")
print(f"TOTAL: {hit}/{found} = {pct:.1f}%")
ok = pct >= floor
print(("PASS" if ok else "FAIL") + f": {pct:.1f}% (floor {floor:.1f}%)")
sys.exit(0 if ok else 1)
