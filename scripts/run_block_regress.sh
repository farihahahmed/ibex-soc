#!/bin/bash
set -euo pipefail
cd /foss/designs/ibex_soc/verification/cocotb
export PYTHONPATH="$(pwd):${PYTHONPATH:-}"
exec ./run_block_regress.sh
