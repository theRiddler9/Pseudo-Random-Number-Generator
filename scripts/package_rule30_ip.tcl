# Package the Rule 30 AXI peripheral into the repository's IP catalog.
# Run from the repository root with Vivado in batch mode:
#   vivado -mode batch -source scripts/package_rule30_ip.tcl

set repo_root [file normalize [file join [file dirname [info script]] ..]]
set ip_root   [file join $repo_root hardware ip_repo rule30_axi_v1_0]
set hdl_dir   [file join $ip_root hdl]
set staging   [file join $repo_root hardware build ip_packager]

file mkdir $staging
create_project -in_memory rule30_ip_packager -part xc7z020clg400-1
add_files -norecurse [list \
    [file join $hdl_dir rule30_core.v] \
    [file join $hdl_dir rule30_axi_v1_0_S00_AXI.v] \
    [file join $hdl_dir rule30_axi_v1_0.v]]
set_property top rule30_axi_v1_0 [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $staging -vendor xilinx.com -library user \
    -taxonomy /UserIP -import_files
set core [ipx::current_core]
set_property name rule30_axi $core
set_property display_name {Rule 30 AXI PRNG} $core
set_property description {Rule 30 cellular automaton PRNG over AXI4-Lite} $core
set_property version 1.0 $core
ipx::save_core $core

file copy -force [file join $staging component.xml] [file join $ip_root component.xml]
close_project
puts "Packaged IP: [file join $ip_root component.xml]"