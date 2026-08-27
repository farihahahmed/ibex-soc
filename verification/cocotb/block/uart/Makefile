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

.PHONY: smoke
smoke:
	$(MAKE) COCOTB_TEST_MODULES=test_uart_smoke

.PHONY: tx
tx:
	$(MAKE) COCOTB_TEST_MODULES=test_uart_tx

.PHONY: tx-random
tx-random:
	$(MAKE) COCOTB_TEST_MODULES=test_uart_tx_random

.PHONY: rx
rx:
	$(MAKE) COCOTB_TEST_MODULES=test_uart_rx

.PHONY: uart-block
uart-block:
	@echo "=== UART block smoke ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_uart_smoke
	@echo "=== UART block TX ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_uart_tx
	@echo "=== UART block TX random ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_uart_tx_random
	@echo "=== UART block RX ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_uart_rx
	@echo "=== UART block MDV finished ==="

.PHONY: tx-byte
tx-byte:
	$(MAKE) COCOTB_TEST_MODULES=test_uart_tx_byte

.PHONY: tx-sb
tx-sb:
	$(MAKE) COCOTB_TEST_MODULES=test_uart_tx_scoreboard

.PHONY: ral stress
ral:
	$(MAKE) COCOTB_TEST_MODULES=test_uart_ral
stress:
	$(MAKE) COCOTB_TEST_MODULES=test_uart_stress

.PHONY: block-regress
protocol:
	$(MAKE) COCOTB_TEST_MODULES=test_uart_protocol

block-regress:
	@echo "=== uart smoke ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_smoke
	@echo "=== uart tx ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx
	@echo "=== uart tx-byte ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx_byte
	@echo "=== uart tx-random ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx_random
	@echo "=== uart rx ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_rx
	@echo "=== uart tx-sb ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx_scoreboard
	@echo === multi scoreboard ===
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_tx_sb_multi
	@echo === uart rx-sb ===
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_rx_scoreboard
	@echo "=== uart RAL (register model) ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_uart_ral
	@echo "=== UART block regress DONE ==="
	$(MAKE) COCOTB_TEST_MODULES=test_uart_protocol

.PHONY: coverage
coverage:
	./run_with_coverage.sh
