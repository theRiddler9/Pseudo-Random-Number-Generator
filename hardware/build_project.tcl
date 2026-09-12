# =============================================================================
# build_project.tcl
# Complete Vivado build script for Rule 30 PRNG on PYNQ-Z2
#
# Run from Vivado Tcl Console:
#   cd {C:/Work/Projects/Hardware Security Primitive Rule 30 Cellular Automaton (PRNG)/hardware}
#   source build_project.tcl
#
# This script:
#   1. Re-packages the IP (with the leds port)
#   2. Creates a Zynq block design
#   3. Adds the system-level testbench (tb_system_wrapper)
#   4. Runs synthesis and implementation
#   5. Generates timing, power, utilization reports
#   6. Exports .bit + .hwh for PYNQ
# =============================================================================

set prj_name "rule30_project"
set prj_dir  "C:/temp/$prj_name"
set src_dir  [pwd]

# Close any stale projects from previous runs
close_project -quiet

puts "============================================================"
puts " PHASE 1: Re-package IP with leds port"
puts "============================================================"

set ip_prj_dir "C:/temp/ip_pkg_project"
create_project -force ip_pkg_project $ip_prj_dir -part xc7z020clg400-1

add_files -norecurse $src_dir/ip_repo/rule30_axi_v1_0/hdl/rule30_axi_v1_0.v
add_files -norecurse $src_dir/ip_repo/rule30_axi_v1_0/hdl/rule30_axi_v1_0_S00_AXI.v
add_files -norecurse $src_dir/ip_repo/rule30_axi_v1_0/hdl/rule30_core.v
update_compile_order -fileset sources_1

ipx::package_project -root_dir $src_dir/ip_repo/rule30_axi_v1_0 \
    -vendor xilinx.com -library user -taxonomy /UserIP -import_files -force
set_property core_revision 4 [ipx::current_core]
ipx::create_xgui_files  [ipx::current_core]
ipx::update_checksums   [ipx::current_core]
ipx::check_integrity    [ipx::current_core]
ipx::save_core          [ipx::current_core]
close_project

puts "============================================================"
puts " PHASE 2: Create Vivado project + Block Design"
puts "============================================================"

create_project -force $prj_name $prj_dir -part xc7z020clg400-1
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]

# Point to our custom IP repo
set_property ip_repo_paths $src_dir/ip_repo [current_project]
update_ip_catalog

# Add constraints
add_files -fileset constrs_1 -norecurse $src_dir/constraints/pynq_z2.xdc

# Create Block Design
create_bd_design "design_1"

# --- Zynq PS ---
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    [get_bd_cells processing_system7_0]

# --- Rule 30 IP ---
create_bd_cell -type ip -vlnv xilinx.com:user:rule30_axi_v1_0:1.0 rule30_axi_0

# --- AXI connection automation ---
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
    Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto}
    Master {/processing_system7_0/M_AXI_GP0}
    Slave  {/rule30_axi_0/S00_AXI}
    ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}
} [get_bd_intf_pins rule30_axi_0/S00_AXI]

# --- Make LEDs external ---
make_bd_pins_external [get_bd_pins rule30_axi_0/leds]
set_property name leds [get_bd_ports leds_0]

regenerate_bd_layout
validate_bd_design
save_bd_design

# --- Print the address map for the user ---
puts ""
puts ">>> Address Map (check SEED_REG and DATA_REG base addr):"
report_bd_address_map
puts ""

puts "============================================================"
puts " PHASE 3: Create HDL wrapper"
puts "============================================================"

make_wrapper -files [get_files $prj_dir/${prj_name}.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse $prj_dir/${prj_name}.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "============================================================"
puts " PHASE 4: Add system-level testbench"
puts "============================================================"

# Add the system-level VIP testbench
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse $src_dir/ip_repo/rule30_axi_v1_0/tb/tb_system_wrapper.v

# Set the testbench as the simulation top for ALL simulation types
set_property top tb_system_wrapper [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1

# Set simulation runtime to 10 us for all sim types
set_property -name {xsim.simulate.runtime} -value {10us} -objects [get_filesets sim_1]

puts "============================================================"
puts " PHASE 5: Synthesis + Implementation + Bitstream"
puts "============================================================"
puts "This will take 5-15 minutes. Please wait..."

launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "Synthesis complete."

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "Implementation + Bitstream complete."

puts "============================================================"
puts " PHASE 6: Generate reports"
puts "============================================================"

open_run impl_1
report_timing_summary -file $src_dir/timing_report.txt
report_power           -file $src_dir/power_report.txt
report_utilization     -file $src_dir/utilization_report.txt

puts "Reports saved to:"
puts "  $src_dir/timing_report.txt"
puts "  $src_dir/power_report.txt"
puts "  $src_dir/utilization_report.txt"

puts "============================================================"
puts " PHASE 7: Export bitstream + HWH for PYNQ"
puts "============================================================"

write_hw_platform -fixed -include_bit -force -file $src_dir/rule30_design.xsa
file copy -force $prj_dir/${prj_name}.runs/impl_1/design_1_wrapper.bit $src_dir/rule30_design.bit
file copy -force $prj_dir/${prj_name}.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh $src_dir/rule30_design.hwh

puts ""
puts "============================================================"
puts " SUCCESS: Full build complete!"
puts ""
puts " Bitstream : $src_dir/rule30_design.bit"
puts " HWH       : $src_dir/rule30_design.hwh"
puts " XSA       : $src_dir/rule30_design.xsa"
puts ""
puts " NEXT STEPS:"
puts "   1. Run Behavioral Simulation from the GUI (Flow Navigator)"
puts "   2. Run Post-Synthesis Functional Simulation"
puts "   3. Run Post-Synthesis Timing Simulation"
puts "   4. Run Post-Implementation Functional Simulation"
puts "   5. Run Post-Implementation Timing Simulation"
puts "   6. Take screenshots of waveforms, schematic, block diagram"
puts "============================================================"
