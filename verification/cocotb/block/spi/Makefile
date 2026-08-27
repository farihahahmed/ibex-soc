
SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = apb_spi
MODULE = test_spi_smoke

VERILOG_SOURCES = ../../../../rtl/apb_spi.sv ../../../../rtl/spi.sv
COMPILE_ARGS += -g2012

export PYTHONPATH := $(abspath ../../../../verification/cocotb):$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke
smoke:
	$(MAKE) MODULE=test_spi_smoke COCOTB_TEST_MODULES=test_spi_smoke

protocol:
	$(MAKE) MODULE=test_spi_protocol

.PHONY: ral
ral:
	$(MAKE) MODULE=test_spi_ral COCOTB_TEST_MODULES=test_spi_ral
