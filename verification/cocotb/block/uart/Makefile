SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = apb_uart

COMPILE_ARGS += -Papb_uart.CLK_FREQ=8
COMPILE_ARGS += -Papb_uart.BAUD_RATE=1

VERILOG_SOURCES = \
  ../../../../rtl/apb_uart.sv \
  ../../../../rtl/uart.sv

export PYTHONPATH := $(abspath ../../../../verification/cocotb):$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke tx tx-byte tx-random tx-neg tx-sb tx-sb-scoreboard tx-sb-multi rx rx-sb protocol ral stress block-regress coverage

smoke:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_smoke

tx:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx

tx-byte:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx_byte

tx-random:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx_random

tx-neg:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx_neg

tx-sb:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx_sb

tx-sb-scoreboard:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx_scoreboard

tx-sb-multi:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx_sb_multi

rx:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_rx

rx-sb:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_rx_scoreboard

protocol:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_protocol

ral:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_ral

stress:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_stress

block-regress:
	@echo "=== uart smoke ==="
	$(MAKE) smoke
	@echo "=== uart tx ==="
	$(MAKE) tx
	@echo "=== uart tx-byte ==="
	$(MAKE) tx-byte
	@echo "=== uart tx-random ==="
	$(MAKE) tx-random
	@echo "=== uart tx-neg ==="
	$(MAKE) tx-neg
	@echo "=== uart tx-sb (pyuvm) ==="
	$(MAKE) tx-sb
	@echo "=== uart tx-sb-scoreboard ==="
	$(MAKE) tx-sb-scoreboard
	@echo "=== uart tx-sb-multi ==="
	$(MAKE) tx-sb-multi
	@echo "=== uart rx ==="
	$(MAKE) rx
	@echo "=== uart rx-sb ==="
	$(MAKE) rx-sb
	@echo "=== uart protocol ==="
	$(MAKE) protocol
	@echo "=== uart ral ==="
	$(MAKE) ral
	@echo "=== uart stress ==="
	$(MAKE) stress
	@echo "=== UART block regress DONE ==="

coverage:
	./run_with_coverage.sh
