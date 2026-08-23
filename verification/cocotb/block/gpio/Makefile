
SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = apb_gpio
MODULE = test_gpio_smoke

VERILOG_SOURCES = /foss/designs/ibex_soc/rtl/apb_gpio.sv /foss/designs/ibex_soc/rtl/gpio.sv
COMPILE_ARGS += -PNUM_OUT=5 -PNUM_IN=2

export PYTHONPATH := /foss/designs/ibex_soc/verification/cocotb:$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke
smoke:
	$(MAKE) MODULE=test_gpio_smoke
