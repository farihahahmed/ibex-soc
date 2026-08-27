SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = scan_chain
COCOTB_TEST_MODULES ?= test_scan_smoke

VERILOG_SOURCES = ../../../../rtl/scan_chain.sv
COMPILE_ARGS += -g2012

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke mem fsm clkgen block-regress

smoke:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_scan_smoke

mem:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_scan_mem

fsm:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_scan_fsm

clkgen:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_scan_clkgen

block-regress:
	@echo "=== scan smoke ==="
	$(MAKE) smoke
	@echo "=== scan mem ==="
	$(MAKE) mem
	@echo "=== scan fsm ==="
	$(MAKE) fsm
	@echo "=== scan clkgen ==="
	$(MAKE) clkgen
	@echo "=== SCAN block regress DONE ==="
