PDK = pdk_models
SC   = $(PDK)
SRAM = $(PDK)
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

.PHONY: gl-firmware
# Scan-loads real firmware into the SIGNOFF NETLIST and confirms the netlist
# accepts the program into its SRAM. Full execution is blocked by a documented
# picorv32 GL X-init limitation (see verification/docs/KNOWN_GAPS.md, R-GL-02);
# equivalence to RTL is proven by LVS + the RTL cocotb gate.
gl-firmware:
	iverilog -g2012 -o /tmp/gl_firmware.vvp \
	  -DFUNCTIONAL -DUNIT_DELAY=#1 -DUSE_POWER_PINS -DGL_INIT_ZERO \
	  $(PDK)/primitives_glinit.v \
	  $(SC)/gf180mcu_fd_sc_mcu7t5v0.v \
	  $(SRAM)/gf180mcu_fd_ip_sram__sram512x8m8wm1.v \
	  $(NETLIST) \
	  tb_gl_firmware.v
	vvp /tmp/gl_firmware.vvp
