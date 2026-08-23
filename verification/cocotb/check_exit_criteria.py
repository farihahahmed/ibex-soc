#!/usr/bin/env python3
"""Pico SoC verification exit criteria (quick status helper)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BLOCK = ROOT / "block"

CRITERIA = [
    ("chip pyuvm tests exist", list((ROOT).glob("test_pyuvm_*.py"))),
    ("block uart", (BLOCK / "uart").is_dir()),
    ("block gpio", (BLOCK / "gpio").is_dir()),
    ("block spi", (BLOCK / "spi").is_dir()),
    ("block mem", (BLOCK / "mem").is_dir()),
    ("block fsm", (BLOCK / "fsm").is_dir()),
    ("block scan", (BLOCK / "scan").is_dir()),
    ("block scan_fsm", (BLOCK / "scan_fsm").is_dir()),
    ("block ahb", (BLOCK / "ahb").is_dir()),
    ("merge_coverage.py", (ROOT / "merge_coverage.py").is_file()),
]

def main():
    ok = True
    print("=== Pico SoC exit-criteria inventory ===")
    for name, cond in CRITERIA:
        if isinstance(cond, list):
            status = len(cond) >= 5
            detail = f"{len(cond)} files"
        else:
            status = bool(cond)
            detail = "yes" if status else "MISSING"
        mark = "PASS" if status else "FAIL"
        if not status:
            ok = False
        print(f"  [{mark}] {name}: {detail}")
    print("---")
    print("Run gates manually:")
    print("  make pyuvm-regress")
    print("  make dmem")
    print("  make -C block block-regress")
    print("  python3 merge_coverage.py")
    print("OVERALL INVENTORY:", "OK" if ok else "GAPS")
    return 0 if ok else 1

if __name__ == "__main__":
    raise SystemExit(main())
