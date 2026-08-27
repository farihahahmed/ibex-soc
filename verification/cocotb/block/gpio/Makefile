
SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = apb_gpio
MODULE = test_gpio_smoke

VERILOG_SOURCES = ../../../../rtl/apb_gpio.sv ../../../../rtl/gpio.sv
COMPILE_ARGS += -PNUM_OUT=5 -PNUM_IN=2

export PYTHONPATH := $(abspath ../../../../verification/cocotb):$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke
smoke:
	$(MAKE) MODULE=test_gpio_smoke

protocol:
	$(MAKE) MODULE=test_gpio_protocol
