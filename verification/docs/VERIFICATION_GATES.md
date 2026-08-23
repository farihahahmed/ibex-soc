# Pico SoC – verification gates

## Must pass (submission)

1. `verification/cocotb/./run_block_regress.sh` → ALL BLOCK MDV PASS
2. `verification/cocotb/./run_all_verify.sh` → ALL VERIFY PASS
   - block regress
   - pyuvm smoke, random, dmem
   - scan lockout (RUN ignores scan IMEM writes)

## Negative tests

| Test | Intent |
|------|--------|
| block/fsm idle-hold | cpu_clk never toggles in IDLE |
| block/ahb hready-stall | slave HREADY=0 stalls master |
| make scan-lockout | scan cannot corrupt image while RUN |
