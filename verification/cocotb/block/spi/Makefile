
SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = apb_spi
MODULE = test_spi_smoke

VERILOG_SOURCES = /foss/designs/pico_soc/rtl/apb_spi.sv /foss/designs/pico_soc/rtl/spi.sv
COMPILE_ARGS += -g2012

export PYTHONPATH := /foss/designs/pico_soc/verification/cocotb:$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke
smoke:
	$(MAKE) MODULE=test_spi_smoke COCOTB_TEST_MODULES=test_spi_smoke
