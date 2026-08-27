#!/usr/bin/env python3
"""Formal verification suite - bounded model checking with Yosys + SMT.

Each target composes the real RTL with a properties module and proves every
assertion holds for ALL input sequences up to the bound. This is stronger than
simulation, which only covers the stimulus a testbench happens to apply.

Run from the repo root or from verification/formal:
    python3 run_formal.py            # all targets
    python3 run_formal.py fabric     # one target
"""
import subprocess, sys, os
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RTL  = ROOT / "rtl"

# name -> (RTL sources, properties file, top module, BMC depth)
TARGETS = {
    "fsm":     (["test_fsm.sv"],                     "test_fsm_formal.sv",   "test_fsm_formal",   20),
    "lockout": (["test_fsm.sv", "scan_chain.sv"],    "lockout_formal.sv",    "lockout_formal",    20),
    "pcpi":    (["pcpi_custom.sv"],                  "pcpi_formal.sv",       "pcpi_formal",       20),
    "gather":  (["fetch_gather.sv"],                 "gather_formal.sv",     "gather_formal",     25),
    "bridge":  (["ahb_to_apb.sv"],                   "bridge_formal.sv",     "bridge_formal",     20),
    "shim":    (["pico_shim.sv"],                    "shim_formal.sv",       "shim_formal",       20),
    "fabric":  (["ahb_interconnect.sv"],             "fabric_formal.sv",     "fabric_formal",     20),
}

SOLVER = os.environ.get("SMT_SOLVER", "yices")


def prove(name):
    srcs, props, top, depth = TARGETS[name]
    files = " ".join(str(RTL / s) for s in srcs) + " " + str(HERE / props)
    smt2  = HERE / f"build_{name}.smt2"
    smt2.parent.mkdir(parents=True, exist_ok=True)

    script = (f"read_verilog -sv {files}; prep -top {top}; "
              f"async2sync; dffunmap; write_smt2 -wires {smt2}")
    r = subprocess.run(["yosys", "-p", script], capture_output=True, text=True)
    if r.returncode != 0 or not smt2.exists():
        print(f"  {name:9s} ELABORATION FAILED")
        print(r.stderr[-1200:] or r.stdout[-1200:])
        return False

    r = subprocess.run(["yosys-smtbmc", "-s", SOLVER, "-t", str(depth), str(smt2)],
                       capture_output=True, text=True)
    ok = "Status: PASSED" in r.stdout
    n  = (HERE / props).read_text().count("assert (")
    print(f"  {name:9s} {'PASSED' if ok else 'FAILED'}   "
          f"{n:2d} properties, depth {depth}")
    if not ok:
        for line in r.stdout.splitlines():
            if "Assert failed" in line:
                print("      " + line.strip())
    return ok


def main():
    names = sys.argv[1:] or list(TARGETS)
    bad = [n for n in names if n not in TARGETS]
    if bad:
        sys.exit(f"unknown target(s): {bad}. Available: {list(TARGETS)}")

    print("Formal verification - bounded model checking")
    print(f"Solver: {SOLVER}\n")
    results = {n: prove(n) for n in names}
    total = sum((HERE / TARGETS[n][1]).read_text().count("assert (") for n in names)
    print()
    if all(results.values()):
        print(f"=== ALL FORMAL PASSED: {total} properties across {len(names)} targets ===")
        return 0
    print("=== FORMAL FAILED: " +
          ", ".join(n for n, ok in results.items() if not ok) + " ===")
    return 1


if __name__ == "__main__":
    sys.exit(main())
