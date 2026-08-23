# Code coverage – Pico SoC

## Official gates
1. **Functional (primary):** `make pyuvm-regress` + `make dmem` all PASS  
2. **RTL glue line (Verilator, no picorv32/SRAM):** ≥ ~70%  
3. Overall toggle % is secondary (wide bus bits)

## dmem
- Directed: `make dmem` — SW/LW @ 0x10, value 0x15 observed on GPIO  
- Narrow-mem gather FSM has many line points; a single word access does not max `dmem_narrow_top` %  
- Functional path is verified; denser traffic is optional polish

## Refresh RTL numbers
```bash
cd verification/cocotb
touch coverage_rtl/sim_main.cpp
# verilator --cc --coverage --exe --build ... (see Makefile coverage-rtl)
./coverage_rtl/obj_dir/cov_sim

## Block UART
- Directed: cd verification/cocotb/block/uart && make smoke
- TX scoreboard: COCOTB_TEST_MODULES=test_uart_tx_sb make (PASS)
- Negative mismatch: test_uart_tx_neg must FAIL
