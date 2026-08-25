drc off
gds read openlane/chip_top_full/runs/RUN_2026-08-24_22-15-30/final/gds/chip_top_full.gds
load chip_top_full
box 188.435um 274.70um 240.000um 275.26um
paint m3
box 240.000um 274.70um 276.985um 275.26um
paint m3
box 628.435um 274.70um 716.985um 275.26um
paint m3
gds write gds/chip_top_full_healed.gds
puts "HEAL DONE"
quit -noprompt
