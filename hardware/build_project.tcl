# build_project.tcl
# Run this script from the Vivado Tcl Console (Tools -> Run Tcl Script...)
# Make sure your current working directory in Vivado is the 'hardware' folder.
# e.g., cd {C:/Work/Projects/Hardware Security Primitive Rule 30 Cellular Automaton (PRNG)/hardware}

set prj_name "rule30_project"
set prj_dir "C:/temp/$prj_name"

# 0. Close any currently open projects to avoid conflicts
close_project -quiet

# 2. Update the IP (Package it in a temporary project first)
set ip_prj_dir "C:/temp/ip_pkg_project"
create_project -force ip_pkg_project $ip_prj_dir -part xc7z020clg400-1
add_files -norecurse ./ip_repo/rule30_axi_v1_0/hdl/rule30_axi_v1_0.v
add_files -norecurse ./ip_repo/rule30_axi_v1_0/hdl/rule30_axi_v1_0_S00_AXI.v
add_files -norecurse ./ip_repo/rule30_axi_v1_0/hdl/rule30_core.v
update_compile_order -fileset sources_1

# Re-package the IP so Vivado sees the new 'leds' port
ipx::package_project -root_dir ./ip_repo/rule30_axi_v1_0 -vendor xilinx.com -library user -taxonomy /UserIP -import_files -force
set_property core_revision 3 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project

# Now create the actual Block Design Project
create_project -force $prj_name $prj_dir -part xc7z020clg400-1
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]

set_property ip_repo_paths ./ip_repo [current_project]
update_ip_catalog

# 3. Add Constraints
add_files -fileset constrs_1 -norecurse ./constraints/pynq_z2.xdc

# 4. Create Block Design
create_bd_design "design_1"

# Add Zynq PS
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

# Add Rule 30 IP
create_bd_cell -type ip -vlnv xilinx.com:user:rule30_axi_v1_0:1.0 rule30_axi_0

# Automate AXI Connection
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/rule30_axi_0/S00_AXI} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins rule30_axi_0/S00_AXI]

# Make LEDs external and connect to the XDC port
make_bd_pins_external  [get_bd_pins rule30_axi_0/leds]
set_property name leds [get_bd_ports leds_0]

# Finalize Block Design
regenerate_bd_layout
validate_bd_design
save_bd_design

# 5. Create HDL Wrapper
make_wrapper -files [get_files $prj_dir/${prj_name}.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse $prj_dir/${prj_name}.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

# 6. Launch Synthesis and Implementation
puts "Starting Synthesis and Implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# 7. Generate Reports
open_run impl_1
report_timing_summary -file timing_report.txt
report_power -file power_report.txt
report_utilization -file utilization_report.txt

# 8. Export Hardware for PYNQ (.xsa)
write_hw_platform -fixed -include_bit -force -file ./rule30_design.xsa
# Also copy bitstream and hwh for PYNQ
file copy -force $prj_dir/${prj_name}.runs/impl_1/design_1_wrapper.bit ./rule30_design.bit
file copy -force $prj_dir/${prj_name}.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh ./rule30_design.hwh

puts "=========================================================="
puts "SUCCESS: Build complete! Bitstream generated and reports saved."
puts "=========================================================="
