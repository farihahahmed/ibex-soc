SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = apb_gpio
MODULE = test_gpio_smoke

VERILOG_SOURCES = ../../../../rtl/apb_gpio.sv ../../../../rtl/gpio.sv
COMPILE_ARGS += -PNUM_OUT=5 -PNUM_IN=2

export PYTHONPATH := $(abspath ../../../../verification/cocotb):$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke write read out random protocol ral inout block-regress

smoke:
	$(MAKE) clean && $(MAKE) MODULE=test_gpio_smoke COCOTB_TEST_MODULES=test_gpio_smoke

write:
	$(MAKE) clean && $(MAKE) MODULE=test_gpio_write COCOTB_TEST_MODULES=test_gpio_write

read:
	$(MAKE) clean && $(MAKE) MODULE=test_gpio_read COCOTB_TEST_MODULES=test_gpio_read

out:
	$(MAKE) clean && $(MAKE) MODULE=test_gpio_out COCOTB_TEST_MODULES=test_gpio_out

random:
	$(MAKE) clean && $(MAKE) MODULE=test_gpio_random COCOTB_TEST_MODULES=test_gpio_random

protocol:
	$(MAKE) clean && $(MAKE) MODULE=test_gpio_protocol COCOTB_TEST_MODULES=test_gpio_protocol

ral:
	$(MAKE) clean && $(MAKE) MODULE=test_gpio_ral COCOTB_TEST_MODULES=test_gpio_ral

inout:
	$(MAKE) clean && $(MAKE) MODULE=test_gpio_inout COCOTB_TEST_MODULES=test_gpio_inout

block-regress:
	@echo "=== gpio smoke ==="
	$(MAKE) smoke
	@echo "=== gpio write ==="
	$(MAKE) write
	@echo "=== gpio read ==="
	$(MAKE) read
	@echo "=== gpio out ==="
	$(MAKE) out
	@echo "=== gpio random ==="
	$(MAKE) random
	@echo "=== gpio protocol ==="
	$(MAKE) protocol
	@echo "=== gpio ral ==="
	$(MAKE) ral
	@echo "=== gpio inout ==="
	$(MAKE) inout
	@echo "=== GPIO block regress DONE ==="
