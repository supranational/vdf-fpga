
create_clock -period 10.000 -name ap_clk -waveform {0.000 5.000} [get_ports ap_clk]

create_pblock sl_exclusion
resize_pblock [get_pblocks sl_exclusion] -add {CLOCKREGION_X4Y0:CLOCKREGION_X5Y9}
set_property EXCLUDE_PLACEMENT 1 [get_pblocks sl_exclusion]
create_pblock SLR2
add_cells_to_pblock [get_pblocks SLR2] [get_cells -quiet [list inst_wrapper/inst_kernel/msu/modsqr/modsqr]]
resize_pblock [get_pblocks SLR2] -add {CLOCKREGION_X0Y10:CLOCKREGION_X5Y14}
