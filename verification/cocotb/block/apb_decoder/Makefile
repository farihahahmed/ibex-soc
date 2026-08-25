SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = apb_decoder
VERILOG_SOURCES = /foss/designs/pico_soc/rtl/apb_decoder.sv
COMPILE_ARGS += -g2012
export PYTHONPATH := /foss/designs/pico_soc/verification/cocotb:$(PYTHONPATH)
COCOTB_TEST_MODULES ?= test_decoder_smoke
include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke decode block-regress
smoke:
	$(MAKE) COCOTB_TEST_MODULES=test_decoder_smoke
decode:
	$(MAKE) COCOTB_TEST_MODULES=test_decoder_regions

block-regress:
	@echo "=== decoder smoke ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_decoder_smoke
	@echo "=== decoder regions ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_decoder_regions
	@echo "=== APB decoder regress DONE ==="
