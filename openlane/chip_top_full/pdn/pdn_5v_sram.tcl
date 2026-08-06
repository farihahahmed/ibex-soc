# Data-memory SRAM
define_pdn_grid -macro -instances u_dmem_slave.u_dmem.u_mem.u_sram \
    -name sram_dmem -starts_with POWER \
    -halo "$::env(PDN_HORIZONTAL_HALO) $::env(PDN_VERTICAL_HALO)"
add_pdn_connect -grid sram_dmem -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"
add_pdn_connect -grid sram_dmem -layers "$::env(PDN_VERTICAL_LAYER) Metal3"
add_pdn_stripe -grid sram_dmem -layer Metal4 -width 2.36 -offset 1.18 \
    -spacing 0.28 -pitch 426.86 -starts_with GROUND -number_of_straps 2
add_pdn_stripe -grid sram_dmem -layer Metal4 -width 4.00 -offset 65.93 \
    -spacing 0.28 -pitch 50 -starts_with GROUND -number_of_straps 7

# Instruction-memory SRAM
define_pdn_grid -macro -instances u_mem.u_imem.u_mem.u_sram \
    -name sram_imem -starts_with POWER \
    -halo "$::env(PDN_HORIZONTAL_HALO) $::env(PDN_VERTICAL_HALO)"
add_pdn_connect -grid sram_imem -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"
add_pdn_connect -grid sram_imem -layers "$::env(PDN_VERTICAL_LAYER) Metal3"
add_pdn_stripe -grid sram_imem -layer Metal4 -width 2.36 -offset 1.18 \
    -spacing 0.28 -pitch 426.86 -starts_with GROUND -number_of_straps 2
add_pdn_stripe -grid sram_imem -layer Metal4 -width 4.00 -offset 65.93 \
    -spacing 0.28 -pitch 50 -starts_with GROUND -number_of_straps 7





