# ============================================================================
# setup_vivado_project.tcl
# Reproducible project bring-up for the Rule 30 hardware PRNG on PYNQ-Z2.
#
# Run from Vivado Tcl console OR batch mode:
#   vivado -mode batch -source scripts/setup_vivado_project.tcl
#
# Prereqs:
#   - PYNQ-Z2 board files installed into Vivado's board_files directory
#     (TUL/Xilinx boards repo: search "pynq-z2 vivado board files").
#   - This script assumes it is run from the repo root.
# ============================================================================

set proj_name   "rule30_prng"
set proj_dir    "./hardware/build/vivado_project"
set ip_repo_dir "./hardware/ip_repo"
set board_part  "tul.com.tw:pynq-z2:part0:1.0"

# ---- 1. Create project ----
create_project $proj_name $proj_dir -part xc7z020clg400-1 -force
set_property board_part $board_part [current_project]

# ---- 2. Register the custom IP repo ----
set_property ip_repo_paths $ip_repo_dir [current_fileset]
update_ip_catalog

# ---- 3. Create block design ----
create_bd_design "system"

# ---- 4. Add Zynq PS and run board-specific automation ----
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} \
    [get_bd_cells processing_system7_0]

# ---- 5. Add the custom Rule 30 AXI IP ----
# NOTE: VLNV below assumes default packager settings (vendor xilinx.com,
# library user, version 1.0). Check Tools > Report > Report IP Status
# or the packaged component.xml if this VLNV doesn't match after packaging.
create_bd_cell -type ip -vlnv xilinx.com:user:rule30_axi:1.0 rule30_axi_0

# ---- 6. Auto-connect AXI interconnect + reset ----
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { Master "/processing_system7_0/M_AXI_GP0" Clk "Auto" } \
    [get_bd_intf_pins rule30_axi_0/s00_axi]

# ---- 7. Validate and generate wrapper ----
regenerate_bd_layout
validate_bd_design
make_wrapper -files [get_files ./$proj_dir/$proj_name.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse ./$proj_dir/$proj_name.gen/sources_1/bd/system/hdl/system_wrapper.v
set_property top system_wrapper [current_fileset]

# ---- 8. Add constraints (only needed if you expose PL pins e.g. LEDs) ----
add_files -fileset constrs_1 ./hardware/constraints/pynq_z2.xdc

# ---- 9. Run synthesis, implementation, bitstream ----
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# ---- 10. Copy out .bit and .hwh with matching names for PYNQ ----
file mkdir ./hardware/build/output
file copy -force \
    ./$proj_dir/$proj_name.runs/impl_1/system_wrapper.bit \
    ./hardware/build/output/rule30_prng.bit
file copy -force \
    ./$proj_dir/$proj_name.gen/sources_1/bd/system/hw_handoff/system.hwh \
    ./hardware/build/output/rule30_prng.hwh

puts "\nBuild complete. Deploy ./hardware/build/output/rule30_prng.{bit,hwh} to the board."
puts "Next: check hardware Address Editor (Window > Address Editor) to confirm"
puts "the rule30_axi_0 base address matches DEFAULT_BASE_ADDR in"
puts "software/driver/rule30_driver.py -- update it if Vivado assigned a"
puts "different address than 0x43C00000."
