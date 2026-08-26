SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = ahb_interconnect

VERILOG_SOURCES = ../../../../rtl/ahb_interconnect.sv
COMPILE_ARGS += -g2012

export PYTHONPATH := $(abspath ../../../../verification/cocotb):$(PYTHONPATH)
COCOTB_TEST_MODULES ?= test_ahb_smoke

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke decode mux hready-stall block-regress
smoke:
	$(MAKE) COCOTB_TEST_MODULES=test_ahb_smoke
decode:
	$(MAKE) COCOTB_TEST_MODULES=test_ahb_decode
mux:
	$(MAKE) COCOTB_TEST_MODULES=test_ahb_mux
hready-stall:
	$(MAKE) COCOTB_TEST_MODULES=test_ahb_hready_stall

block-regress:
	@echo "=== ahb smoke ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_ahb_smoke
	@echo "=== ahb decode ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_ahb_decode
	@echo "=== ahb mux ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_ahb_mux
	@echo "=== ahb hready-stall ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_ahb_hready_stall
	@echo "=== AHB block regress DONE ==="
