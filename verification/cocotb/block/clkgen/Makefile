SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = clk_gen

VERILOG_SOURCES = /foss/designs/ibex_soc/rtl/clk_gen.sv
COMPILE_ARGS += -g2012

export PYTHONPATH := /foss/designs/ibex_soc/verification/cocotb:$(PYTHONPATH)
COCOTB_TEST_MODULES ?= test_clkgen_smoke

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke external div block-regress
smoke:
	$(MAKE) COCOTB_TEST_MODULES=test_clkgen_smoke
external:
	$(MAKE) COCOTB_TEST_MODULES=test_clkgen_external
div:
	$(MAKE) COCOTB_TEST_MODULES=test_clkgen_div

block-regress:
	@echo "=== clkgen smoke ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_clkgen_smoke
	@echo "=== clkgen external ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_clkgen_external
	@echo "=== clkgen div ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_clkgen_div
	@echo "=== CLKGEN block regress DONE ==="
