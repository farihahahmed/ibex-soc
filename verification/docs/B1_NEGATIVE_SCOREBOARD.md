# B1 – Negative scoreboard check

`test_pyuvm_neg_gpio.py` sets `expected_gpio = 0x1A` while DUT drives `0x05`.

**Required outcome:** FAIL with `[SB] GPIO 0x1a never seen`.

Run:
```bash
make COCOTB_TEST_MODULES=test_pyuvm_neg_gpio
# must FAIL
Positive control remains make smoke (PASS).
