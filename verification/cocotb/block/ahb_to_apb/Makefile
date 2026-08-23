SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = ahb_to_apb

VERILOG_SOURCES = /foss/designs/ibex_soc/rtl/ahb_to_apb.sv
COMPILE_ARGS += -g2012

export PYTHONPATH := /foss/designs/ibex_soc/verification/cocotb:$(PYTHONPATH)
COCOTB_TEST_MODULES ?= test_bridge_smoke

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke write read stall block-regress
smoke:
	$(MAKE) COCOTB_TEST_MODULES=test_bridge_smoke
write:
	$(MAKE) COCOTB_TEST_MODULES=test_bridge_write
read:
	$(MAKE) COCOTB_TEST_MODULES=test_bridge_read

block-regress:
	@echo "=== bridge smoke ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_bridge_smoke
	@echo "=== bridge write ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_bridge_write
	@echo "=== bridge read ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_bridge_read
	@echo "=== AHB-to-APB bridge regress DONE ==="
