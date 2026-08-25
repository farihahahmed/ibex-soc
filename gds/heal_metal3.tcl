drc off
gds read openlane/chip_top_full/runs/RUN_2026-08-25_06-27-25/final/gds/chip_top_full.gds
load chip_top_full
box 238.435um 330.70um 240.000um 331.26um
paint m3
box 240.000um 330.70um 326.985um 331.26um
paint m3
box 678.435um 330.70um 720.000um 331.26um
paint m3
box 720.000um 330.70um 766.985um 331.26um
paint m3
gds write gds/chip_top_full_healed.gds
puts "HEAL DONE"
quit -noprompt
