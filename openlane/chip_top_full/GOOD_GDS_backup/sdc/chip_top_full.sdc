###############################################################################
# Created by write_sdc
###############################################################################
current_design chip_top_full
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk -period 100.0000 [get_ports {clk}]
set_propagated_clock [get_clocks {clk}]
create_generated_clock -name sys_clk -source [get_ports {clk}] -divide_by 2 [get_pins {_09912_/Z}]
set_propagated_clock [get_clocks {sys_clk}]
create_generated_clock -name cpu_clk -source [get_pins {_09912_/Z}] -divide_by 1 [get_pins {_09913_/Z}]
set_propagated_clock [get_clocks {cpu_clk}]
###############################################################################
# Environment
###############################################################################
###############################################################################
# Design Rules
###############################################################################
