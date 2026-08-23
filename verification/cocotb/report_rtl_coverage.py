#!/usr/bin/env python3
"""Verilator glue LINE coverage (strips binary tags in .dat)."""
import re
import sys
from pathlib import Path
from collections import defaultdict

DAT = Path("coverage_rtl/obj_dir/coverage.dat")
if not DAT.is_file():
    print(f"MISSING {DAT}")
    sys.exit(1)

SKIP = ("picorv32", "gf180", "sram")
pts, hit = defaultdict(int), defaultdict(int)

raw = DAT.read_bytes()
# drop Verilator hierarchical tags
text = raw.replace(b"\x01", b"").replace(b"\x02", b"").decode("utf-8", "ignore")

for L in text.splitlines():
    if not L.startswith("C "):
        continue
    if "line" not in L:  # line / linepage
        continue
    if "toggle" in L:
        continue
    mfile = re.search(r"f([^'\s]+\.(?:sv|v))", L)
    mnum = re.search(r"\s(\d+)\s*$", L)
    if not mfile or not mnum:
        continue
    f = mfile.group(1).split("/")[-1]
    n = int(mnum.group(1))
    if any(s in f.lower() for s in SKIP):
        continue
    pts[f] += 1
    if n > 0:
        hit[f] += 1

tot_p, tot_h = sum(pts.values()), sum(hit.values())
pct = 100.0 * tot_h / max(tot_p, 1)
print(f"GLUE LINE coverage: {tot_h}/{tot_p} = {pct:.1f}%")
for f in sorted(pts, key=lambda x: -pts[x])[:20]:
    h, p = hit[f], pts[f]
    print(f"  {f:28} {h:4}/{p:4}  {100.0*h/max(p,1):5.1f}%")

GATE = 70.0
ok = pct >= GATE
print(("PASS" if ok else "FAIL") + f": glue line {pct:.1f}% (gate {GATE}%)")
sys.exit(0 if ok else 1)
