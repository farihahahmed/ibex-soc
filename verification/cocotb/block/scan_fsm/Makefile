SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = scan_fsm_wrap
COCOTB_TEST_MODULES ?= test_scan_fsm_int

VERILOG_SOURCES = \
  scan_fsm_wrap.sv \
  ../../../../rtl/scan_chain.sv \
  ../../../../rtl/test_fsm.sv

COMPILE_ARGS += -g2012
export PYTHONPATH := $(abspath ../../../../verification/cocotb):$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: int block-regress
int:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_scan_fsm_int

block-regress:
	@echo "=== scan+fsm integration ==="
	$(MAKE) int
	@echo "=== scan+fsm countdown ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_scan_fsm_countdown
	@echo "=== SCAN+FSM int DONE ==="
