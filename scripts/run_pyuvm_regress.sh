#!/bin/bash
set -euo pipefail
# Core root is two levels up from scripts/ when invoked via fusesoc from repo,
# but build dir may differ — resolve from this script location.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/verification/cocotb"
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"
echo "=== FuseSoC → pyuvm-regress (ROOT=$ROOT) ==="
make pyuvm-regress
echo "=== FuseSoC pyuvm-regress DONE ==="
