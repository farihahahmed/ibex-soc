#!/usr/bin/env python3
"""Parse Verilator coverage.dat → glue line % report (CI artifact)."""
import re
import sys
import json
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
DAT = ROOT / "verification/cocotb/coverage_rtl/obj_dir/coverage.dat"
OUT_DIR = ROOT / "verification/coverage_artifacts"
OUT_JSON = OUT_DIR / "rtl_coverage.json"
OUT_MD = OUT_DIR / "rtl_coverage.md"

# Exclude heavy / macro noise from "glue" gate
EXCLUDE = ("picorv32", "gf180", "sram")

def main():
    if not DAT.exists():
        print(f"MISSING {DAT} — run cov_sim first", file=sys.stderr)
        return 1

    line_pts = defaultdict(int)
    line_hit = defaultdict(int)

    for L in DAT.read_text(errors="ignore").splitlines():
        if not L.startswith("C "):
            continue
        # line coverage only
        if "tline" not in L and "v_line" not in L:
            continue
        mnum = re.search(r"\s(\d+)\s*$", L)
        n = int(mnum.group(1)) if mnum else 0
        m = re.search(r"([\w./]+\.(?:sv|v))", L)
        if not m:
            continue
        fname = m.group(1).split("/")[-1]
        line_pts[fname] += 1
        if n > 0:
            line_hit[fname] += 1

    glue_t = glue_h = 0
    rows = []
    for f in sorted(line_pts):
        pts = line_pts[f]
        h = line_hit[f]
        pct = 100.0 * h / pts if pts else 0
        is_glue = not any(x in f.lower() for x in EXCLUDE)
        if is_glue:
            glue_t += pts
            glue_h += h
        rows.append({"file": f, "hit": h, "pts": pts, "pct": round(pct, 1), "glue": is_glue})

    glue_pct = 100.0 * glue_h / glue_t if glue_t else 0.0
    gate = 70.0
    passed = glue_pct >= gate

    report = {
        "glue_line_hit": glue_h,
        "glue_line_pts": glue_t,
        "glue_line_pct": round(glue_pct, 1),
        "gate_pct": gate,
        "pass": passed,
        "files": rows,
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(report, indent=2))

    md = [
        "# RTL line coverage (Verilator)",
        "",
        f"**Glue line:** {glue_h}/{glue_t} = **{glue_pct:.1f}%** (gate ≥ {gate:.0f}%)",
        f"**Status:** {'PASS' if passed else 'FAIL'}",
        "",
        "| File | Hit | Pts | % | Glue |",
        "|------|----:|----:|----:|:----:|",
    ]
    for r in rows:
        md.append(f"| `{r['file']}` | {r['hit']} | {r['pts']} | {r['pct']} | {'Y' if r['glue'] else ''} |")
    OUT_MD.write_text("\n".join(md) + "\n")

    print(OUT_MD.read_text())
    print(f"Wrote {OUT_JSON} and {OUT_MD}")
    return 0 if passed else 1

if __name__ == "__main__":
    sys.exit(main())
