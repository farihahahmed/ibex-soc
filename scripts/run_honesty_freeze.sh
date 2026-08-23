#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../verification/cocotb"
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"
./run_all_verify.sh
