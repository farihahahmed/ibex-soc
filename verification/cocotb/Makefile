SIM ?= icarus
TOPLEVEL_LANG = verilog
WAVES ?= 0

TOPLEVEL = chip_top_full
COCOTB_TEST_MODULES ?= test_chip_basic

VERILOG_SOURCES = $(shell find ../../rtl -name "*.v" -o -name "*.sv" | sort)
VERILOG_SOURCES += models/gf180mcu_fd_ip_sram__sram512x8m8wm1.v
# Behavioural model of the PDK integrated clock gate used by clk_gen. The full
# PDK cell library cannot be read by Icarus (ifnone in specify blocks).
VERILOG_SOURCES += models/gf180mcu_fd_sc_mcu7t5v0__icgtp_1.v

COMPILE_ARGS += -Pchip_top_full.NUM_OUT=5
COMPILE_ARGS += -Pchip_top_full.NUM_IN=2
COMPILE_ARGS += -Pchip_top_full.CLK_FREQ=8
COMPILE_ARGS += -Pchip_top_full.BAUD_RATE=1
COMPILE_ARGS += -Pchip_top_full.SPI_CLK_DIV=2

export PYTHONPATH := $(CURDIR):$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke random primes game pyuvm-regress

smoke:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_smoke

random:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_random

primes:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_primes

game:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_game

pyuvm-regress:
	@echo "=== pyuvm smoke ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_smoke
	@echo "=== pyuvm random gpio ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_random
	@echo "=== pyuvm random uart ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_random_uart
	@echo "=== pyuvm random spi ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_random_spi
	@echo "=== pyuvm uart rx e2e ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_uart_rx_e2e
	@echo "=== pyuvm primes ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_primes
	@echo "=== pyuvm piezo ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_piezo
	@echo "=== pyuvm game ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_game
	@echo "=== pyuvm dmem ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_dmem
	@echo "=== pyuvm concurrent ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_concurrent
	@echo "=== scan-corners ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_scan_corners
	@echo "=== rerun ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_rerun
	@echo "=== illegal-addr ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_illegal_addr
	@echo "=== dmem-stress ==="
	$(MAKE) clean
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_dmem_stress
	@echo "=== coverage-merge ==="
	python3 merge_coverage.py
	@echo "=== pyuvm regression finished ==="

ifeq ($(COVERAGE),1)
COMPILE_ARGS += -DCOVERAGE
endif

piezo:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_piezo

.PHONY: coverage-rtl fusesoc-sim coverage-merge

coverage-rtl:
	mkdir -p coverage_rtl
	verilator --cc --coverage --timing --top-module chip_top_full \
	  -Wno-fatal -Wno-TIMESCALEMOD -Wno-DECLFILENAME -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
	  -I../../rtl ../../rtl/*.sv ../../rtl/*.v models/*.v \
	  --Mdir coverage_rtl/obj_dir

coverage-merge:
	python3 merge_coverage.py

fusesoc-sim:
	cd ../.. && fusesoc run --target sim --setup --build ::pico_soc:1.0.0

.PHONY: coverage-run
coverage-run:
	verilator --cc --coverage --timing --exe --build \
	  -Wno-fatal -Wno-TIMESCALEMOD -Wno-DECLFILENAME -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
	  -Wno-CASEINCOMPLETE -Wno-UNOPTFLAT \
	  -CFLAGS "-std=c++17" \
	  --top-module chip_top_full \
	  -f coverage_rtl/sources.f \
	  coverage_rtl/sim_main.cpp \
	  --Mdir coverage_rtl/obj_dir \
	  -o cov_sim
	cd coverage_rtl/obj_dir && ./cov_sim && verilator_coverage --rank coverage.dat

.PHONY: random-uart random-spi
random-uart:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_random_uart
random-spi:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_random_spi

.PHONY: random-uart-seeds random-spi-seeds
random-uart-seeds:
	./run_random_uart_seeds.sh
random-spi-seeds:
	./run_random_spi_seeds.sh

.PHONY: uart-rx
uart-rx:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_uart_rx

.PHONY: uart-rx-e2e
uart-rx-e2e:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_uart_rx_e2e

.PHONY: fusesoc-pyuvm
fusesoc-pyuvm:
	cd ../.. && fusesoc run --target pyuvm --setup --build ::pico_soc:1.0.0

.PHONY: dmem scan-corners countdown concurrent
dmem:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_dmem



scan-corners:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_scan_corners

countdown:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_countdown

concurrent:
	$(MAKE) COCOTB_TEST_MODULES=test_pyuvm_concurrent
.PHONY: lint
lint:
	python3 -m py_compile test_pyuvm_smoke.py test_pyuvm_random.py test_pyuvm_dmem.py 2>/dev/null || true
	find tb -name "*.py" -print0 | xargs -0 python3 -m py_compile
	@echo "lint OK"

.PHONY: gl
gl:
	$(MAKE) -C ../gl gl-smoke

.PHONY: block-regress
block-regress:
	./run_block_regress.sh

	@echo "=== CHIP REGRESS DONE ==="

.PHONY: block-uart block-spi block-gpio block-scan block-fsm block-all verify-all

block-uart:
	$(MAKE) -C block/uart block-regress

block-spi:
	$(MAKE) -C block/spi block-regress

block-gpio:
	$(MAKE) -C block/gpio block-regress


block-scan:
	$(MAKE) -C block/scan block-regress

block-fsm:
	$(MAKE) -C block/fsm block-regress

block-all:
	@echo "======== BLOCK UART ========"
	$(MAKE) -C block/uart block-regress
	@echo "======== BLOCK SPI ========"
	$(MAKE) -C block/spi block-regress
	@echo "======== BLOCK GPIO ========"
	$(MAKE) -C block/gpio block-regress
	@echo "======== BLOCK SCAN ========"
	$(MAKE) -C block/scan block-regress
	@echo "======== BLOCK FSM ========"
	$(MAKE) -C block/fsm block-regress
	@echo "======== BLOCK ALL DONE ========"

verify-all:
	@echo "======== CHIP pyuvm-regress ========"
	$(MAKE) pyuvm-regress
	@echo "======== BLOCK ALL ========"
	$(MAKE) block-all
	@echo "======== VERIFY-ALL DONE ========"

.PHONY: coverage-report
coverage-report:
	python3 report_rtl_coverage.py
