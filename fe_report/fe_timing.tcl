read_liberty /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib
read_liberty /foss/designs/pico_soc/openlane/chip_top_full/macros/sram512x8.lib
read_verilog /foss/designs/pico_soc/fe_report/chip_top_full.synth.v
link_design chip_top_full
# primary input clock only; generated clocks not defined here (front-end estimate)
create_clock -name clk -period 40.0 [get_ports clk]
# IDEAL clocks — no CTS/wire delay yet (this is the pre-layout estimate)
puts "===== WORST SETUP PATH (pre-layout, ideal wires) ====="
report_checks -path_delay max -digits 3 -group_count 3
puts "===== WORST SETUP SLACK ====="
report_worst_slack -max -digits 3
puts "===== CRITICAL PATH LENGTH (data arrival at worst endpoint) ====="
report_check_types -max_slew -max_capacitance -violators -digits 3 | tail -5
