drc off
gds read openlane/chip_top_full/runs/RUN_2026-08-08_06-31-45/final/gds/chip_top_full.gds
load chip_top_full
box 158.435um 650.80um 240.000um 651.36um
paint m3
box 240.000um 650.80um 246.985um 651.36um
paint m3
box 638.435um 650.80um 720.000um 651.36um
paint m3
box 720.000um 650.80um 726.985um 651.36um
paint m3
gds write /tmp/healed2.gds
puts "HEAL DONE"
quit -noprompt
