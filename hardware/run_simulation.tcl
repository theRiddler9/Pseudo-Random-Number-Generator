# run_simulation.tcl
# Run this from Vivado Tcl Console to launch the simulation for the Rule 30 AXI testbench.
# cd {C:/Work/Projects/Hardware Security Primitive Rule 30 Cellular Automaton (PRNG)/hardware}

set prj_name "sim_project"
set prj_dir "C:/temp/$prj_name"

# Close any currently open projects
close_project -quiet

create_project -force $prj_name $prj_dir -part xc7z020clg400-1

# Add RTL
add_files -norecurse ./ip_repo/rule30_axi_v1_0/hdl/rule30_axi_v1_0.v
add_files -norecurse ./ip_repo/rule30_axi_v1_0/hdl/rule30_axi_v1_0_S00_AXI.v
add_files -norecurse ./ip_repo/rule30_axi_v1_0/hdl/rule30_core.v

# Add TB
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse ./ip_repo/rule30_axi_v1_0/tb/tb_rule30_axi_bfm.v
add_files -fileset sim_1 -norecurse ./ip_repo/rule30_axi_v1_0/tb/tb_rule30_core.v
update_compile_order -fileset sim_1

set_property top tb_rule30_axi_bfm [get_filesets sim_1]

launch_simulation
run 10 us

puts "=========================================================="
puts "Simulation finished! You can view the waveforms in the GUI."
puts "Take a screenshot of the waveform to save as waveform.png."
puts "=========================================================="
