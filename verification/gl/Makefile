PDK ?= /foss/pdks/ciel/gf180mcu/versions/7b70722e33c03fcb5dabcf4d479fb0822d9251c9/gf180mcuD
SC   = $(PDK)/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog
SRAM = $(PDK)/libs.ref/gf180mcu_fd_ip_sram/verilog
# Current signoff netlist, kept in gds/ alongside the GDS it matches.
NETLIST = ../../gds/chip_top_full.pnl.v

.PHONY: gl-smoke
gl-smoke:
	iverilog -g2012 -o /tmp/gl_smoke.vvp \
	  -DFUNCTIONAL -DUNIT_DELAY=#1 -DUSE_POWER_PINS \
	  $(SC)/primitives.v \
	  $(SC)/gf180mcu_fd_sc_mcu7t5v0.v \
	  $(SRAM)/gf180mcu_fd_ip_sram__sram256x8m8wm1.v \
	  $(SRAM)/gf180mcu_fd_ip_sram__sram64x8m8wm1.v \
	  $(NETLIST) \
	  tb_gl_smoke.v
	vvp /tmp/gl_smoke.vvp
