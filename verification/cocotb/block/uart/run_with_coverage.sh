#!/usr/bin/env bash
# Block UART – functional regress + Verilator coverage model
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
RTL=../../../../rtl

echo "=== (1) Functional UART block-regress ==="
make block-regress

echo ""
echo "=== (2) Verilator coverage model (apb_uart + uart) ==="
mkdir -p coverage_out
verilator --cc --coverage --top-module apb_uart \
  -Wno-fatal -Wno-TIMESCALEMOD -Wno-DECLFILENAME \
  -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-CASEINCOMPLETE \
  "$RTL/apb_uart.sv" "$RTL/uart.sv" \
  --Mdir coverage_out/obj_dir

echo ""
echo "=== (3) Summary ==="
echo "Functional gate: block-regress PASS (above)"
echo "Verilator model: coverage_out/obj_dir/"
ls coverage_out/obj_dir | head -12
echo "Annotated dump needs a C++ harness (optional; chip flow has coverage_rtl/)."
echo "=== run_with_coverage DONE ==="
