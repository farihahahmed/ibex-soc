SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = test_fsm
COCOTB_TEST_MODULES ?= test_fsm_smoke

VERILOG_SOURCES = ../../../../rtl/test_fsm.sv
COMPILE_ARGS += -g2012

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke run countdown idle-hold block-regress

smoke:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_fsm_smoke

run:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_fsm_run

countdown:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_fsm_countdown

idle-hold:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_fsm_idle_hold

block-regress:
	@echo "=== fsm smoke ==="
	$(MAKE) smoke
	@echo "=== fsm run ==="
	$(MAKE) run
	@echo "=== fsm countdown ==="
	$(MAKE) countdown
	@echo "=== fsm idle-hold ==="
	$(MAKE) idle-hold
	@echo "=== FSM block regress DONE ==="
