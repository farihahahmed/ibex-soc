read_liberty $env(LIB)
read_verilog /tmp/chip_sta3.v
link_design chip_top_full
create_clock -name clk -period 125.0 [get_ports clk]
report_worst_slack -max
report_checks -path_delay max -digits 3
exit
