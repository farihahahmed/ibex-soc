PDK = /foss/pdks/gf180mcuD
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
	  $(SRAM)/gf180mcu_fd_ip_sram__sram512x8m8wm1.v \
	  $(NETLIST) \
	  tb_gl_smoke.v
	vvp /tmp/gl_smoke.vvp
