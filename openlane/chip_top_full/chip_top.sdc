# chip_top clocks — on-chip generated + gated (Columbia-style)
create_clock -name clk -period 35.0 [get_ports clk]

set sys_drv [get_pins -of_objects [get_nets sys_clk] -filter {direction == output}]
create_generated_clock -name sys_clk -source [get_ports clk] -divide_by 2 $sys_drv

set cpu_drv [get_pins -of_objects [get_nets cpu_clk] -filter {direction == output}]
create_generated_clock -name cpu_clk -source $sys_drv -divide_by 1 $cpu_drv

set_propagated_clock [all_clocks]
