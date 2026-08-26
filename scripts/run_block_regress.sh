#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../verification/cocotb"
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"
exec ./run_block_regress.sh
