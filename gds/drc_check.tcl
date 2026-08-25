gds read gds/chip_top_full_healed.gds
load chip_top_full
select top cell
drc euclidean on
drc style drc(full)
drc check
drc catchup
set c [drc list count total]
puts "=== DRC VIOLATIONS: $c ==="
quit -noprompt
