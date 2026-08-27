#!/usr/bin/env bash
# Convenience wrapper. There is ONE official verification gate:
#     verification/cocotb/run_all_verify.sh
# This file used to run a smaller, separate test list and masked a dmem
# failure by ignoring its exit status. Both are gone: it now delegates, so the
# gate cannot diverge from itself and nothing is excluded or allowed to fail.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT/verification/cocotb/run_all_verify.sh"
