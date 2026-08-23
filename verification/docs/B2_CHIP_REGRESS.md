# B2 – Chip regress gate

Command:
  cd verification/cocotb
  make chip-regress

Runs positive pyuvm suite + coverage merge (>=5 GPIO bins).

Negative (manual only, must FAIL):
  make COCOTB_TEST_MODULES=test_pyuvm_neg_gpio
