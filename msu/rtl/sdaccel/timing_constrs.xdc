# Required for SDAccel
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets WRAPPER_INST/SH/kernel_clks_i/clkwiz_kernel_clk0/inst/CLK_CORE_DRP_I/clk_inst/clk_out1]

# Designate clock crossings as false paths
set_false_path -from [get_cells WRAPPER_INST/CL/vdf_1/inst/inst_wrapper/inst_kernel/msu/modsqr/reset_e4_reg__0]
set_false_path -from [get_cells WRAPPER_INST/CL/vdf_1/inst/inst_wrapper/inst_kernel/msu/modsqr/valid_in_cdc/valid_in_pulse_reg]
set_false_path -from [get_cells WRAPPER_INST/CL/vdf_1/inst/inst_wrapper/inst_kernel/msu/modsqr/valid_out_cdc/valid_in_pulse_reg]
set_false_path -from [get_cells WRAPPER_INST/CL/vdf_1/inst/inst_wrapper/inst_kernel/msu/modsqr/sq_in_e1_reg*]
set_false_path -from [get_cells WRAPPER_INST/CL/vdf_1/inst/inst_wrapper/inst_kernel/msu/modsqr/sq_out_i1_reg*]

# sq_in and sq_out are multi-cycle paths
# https://www.xilinx.com/video/hardware/setting-multicycle-path-exceptions.html
set_multicycle_path 3 -from [get_cells {WRAPPER_INST/CL/vdf_1/inst/inst_wrapper/inst_kernel/msu/modsqr/sq_in_e1_reg*}]
set_multicycle_path 2 -from [get_cells {WRAPPER_INST/CL/vdf_1/inst/inst_wrapper/inst_kernel/msu/modsqr/sq_in_e1_reg*}] -hold

set_multicycle_path 3 -from [get_cells {WRAPPER_INST/CL/vdf_1/inst/inst_wrapper/inst_kernel/msu/modsqr/sq_out_i1_reg*}]
set_multicycle_path 2 -from [get_cells {WRAPPER_INST/CL/vdf_1/inst/inst_wrapper/inst_kernel/msu/modsqr/sq_out_i1_reg*}] -hold


