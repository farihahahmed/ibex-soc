# Block UART coverage – Pico SoC

## Gates
1. **Functional (required):** `cd verification/cocotb/block/uart && make block-regress`
2. **Coverage model:** `make coverage` or `./run_with_coverage.sh`
   - Runs full block-regress
   - Builds Verilator line/toggle model under `coverage_out/obj_dir/`

## Contents exercised
- smoke, TX start-bit, TX full-byte decode, TX random (multi-seed), RX, TX scoreboard/predictor

## Notes
- Primary signoff is functional + predictor scoreboard.
- Annotated RTL % needs a C++ harness (same pattern as chip `coverage_rtl/`); model build proves the flow is enabled.
