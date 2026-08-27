SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = dmem_narrow_top

VERILOG_SOURCES = \
  ../../../../rtl/dmem_narrow_top.sv \
  ../../../../rtl/dmem_narrow.sv \
  ../../../../verification/cocotb/models/gf180mcu_fd_ip_sram__sram512x8m8wm1.v

COMPILE_ARGS += -g2012

export PYTHONPATH := $(abspath ../../../../verification/cocotb):$(PYTHONPATH)
COCOTB_TEST_MODULES ?= test_dmem_smoke

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke word be imem-load block-regress

smoke:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_dmem_smoke

word:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_dmem_word

be:
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_dmem_be

imem-load:
	$(MAKE) clean && $(MAKE) TOPLEVEL=imem_narrow_top \
	  VERILOG_SOURCES="../../../../rtl/imem_narrow_top.sv \
	    ../../../../rtl/imem_narrow.sv \
	    ../../../../rtl/fetch_gather.sv \
	    ../../../../verification/cocotb/models/gf180mcu_fd_ip_sram__sram512x8m8wm1.v" \
	  COCOTB_TEST_MODULES=test_imem_load

block-regress:
	@echo "=== dmem smoke ==="
	$(MAKE) smoke
	@echo "=== dmem word ==="
	$(MAKE) word
	@echo "=== dmem be ==="
	$(MAKE) be
	@echo "=== imem load ==="
	$(MAKE) imem-load
	@echo "=== MEM block regress DONE ==="
