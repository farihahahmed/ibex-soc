SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = dmem_narrow_top

VERILOG_SOURCES = \
  /foss/designs/ibex_soc/rtl/dmem_narrow_top.sv \
  /foss/designs/ibex_soc/rtl/dmem_narrow.sv \
  /foss/designs/ibex_soc/verification/cocotb/models/gf180mcu_fd_ip_sram__sram64x8m8wm1.v

COMPILE_ARGS += -g2012

export PYTHONPATH := /foss/designs/ibex_soc/verification/cocotb:$(PYTHONPATH)
COCOTB_TEST_MODULES ?= test_dmem_smoke

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: smoke word be block-regress
smoke:
	$(MAKE) COCOTB_TEST_MODULES=test_dmem_smoke
word:
	$(MAKE) COCOTB_TEST_MODULES=test_dmem_word
be:
	$(MAKE) COCOTB_TEST_MODULES=test_dmem_be
block-regress:
	@echo "=== dmem smoke ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_dmem_smoke
	@echo "=== dmem word ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_dmem_word
	@echo "=== dmem be ==="
	$(MAKE) clean && $(MAKE) COCOTB_TEST_MODULES=test_dmem_be
	@echo "=== MEM block regress DONE ==="

# --- imem (separate toplevel) ---
.PHONY: imem-smoke imem-load
imem-smoke:
	$(MAKE) TOPLEVEL=imem_narrow_top \
	  VERILOG_SOURCES="/foss/designs/ibex_soc/rtl/imem_narrow_top.sv \
	    /foss/designs/ibex_soc/rtl/imem_narrow.sv \
	    /foss/designs/ibex_soc/rtl/fetch_gather.sv \
	    /foss/designs/ibex_soc/verification/cocotb/models/gf180mcu_fd_ip_sram__sram256x8m8wm1.v" \
	  COCOTB_TEST_MODULES=test_imem_load

imem-load: imem-smoke
