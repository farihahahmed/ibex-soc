SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = apb_spi
MODULE = test_spi_smoke

VERILOG_SOURCES = ../../../../rtl/apb_spi.sv ../../../../rtl/spi.sv
COMPILE_ARGS += -g2012

export PYTHONPATH := $(abspath ../../../../verification/cocotb):$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke tx tx-random rx loopback random protocol ral block-regress

smoke:
	$(MAKE) clean && $(MAKE) MODULE=test_spi_smoke COCOTB_TEST_MODULES=test_spi_smoke

tx:
	$(MAKE) clean && $(MAKE) MODULE=test_spi_tx COCOTB_TEST_MODULES=test_spi_tx

tx-random:
	$(MAKE) clean && $(MAKE) MODULE=test_spi_tx_random COCOTB_TEST_MODULES=test_spi_tx_random

rx:
	$(MAKE) clean && $(MAKE) MODULE=test_spi_rx COCOTB_TEST_MODULES=test_spi_rx

loopback:
	$(MAKE) clean && $(MAKE) MODULE=test_spi_loopback COCOTB_TEST_MODULES=test_spi_loopback

random:
	$(MAKE) clean && $(MAKE) MODULE=test_spi_random COCOTB_TEST_MODULES=test_spi_random

protocol:
	$(MAKE) clean && $(MAKE) MODULE=test_spi_protocol COCOTB_TEST_MODULES=test_spi_protocol

ral:
	$(MAKE) clean && $(MAKE) MODULE=test_spi_ral COCOTB_TEST_MODULES=test_spi_ral

block-regress:
	@echo "=== spi smoke ==="
	$(MAKE) smoke
	@echo "=== spi tx ==="
	$(MAKE) tx
	@echo "=== spi tx-random ==="
	$(MAKE) tx-random
	@echo "=== spi rx ==="
	$(MAKE) rx
	@echo "=== spi loopback ==="
	$(MAKE) loopback
	@echo "=== spi random ==="
	$(MAKE) random
	@echo "=== spi protocol ==="
	$(MAKE) protocol
	@echo "=== spi ral ==="
	$(MAKE) ral
	@echo "=== SPI block regress DONE ==="
