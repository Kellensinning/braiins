####################################################################################################
# Copyright (C) 2019  Braiins Systems s.r.o.
#
# This file is part of Braiins Open-Source Initiative (BOSI).
#
# BOSI is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Please, keep in mind that we may also license BOSI or any part thereof
# under a proprietary license. For more information on the terms and conditions
# of such proprietary license or if you have any other questions, please
# contact us at opensource@braiins.com.
####################################################################################################

####################################################################################################
# Generate IP core
####################################################################################################
set ip_name "axi_fan_ctrl"
set ip_library "ip"
set ip_version "1.0"
set ip_vendor "braiins.com"
set src_path [file join src ip_cores $ip_name hdl]
set ip_repo [file join $projdir ip_repo]

# Set list of VHDL files in compilation order
set ip_hdl_files [ list \
    "debouncer.vhd" \
    "pwm_gen.vhd" \
    "fan_ctrl_core.vhd" \
    "fan_ctrl_S_AXI.vhd" \
    "axi_fan_ctrl_v1_0.vhd" \
]

timestamp "Generating IP core ${ip_name} ..."

####################################################################################################
# set VHDL as target language for files generation
set_property target_language VHDL [current_project]

set ip_id "${ip_vendor}:${ip_library}:${ip_name}:${ip_version}"
set ip_repo_path "${ip_repo}/${ip_name}_${ip_version}"

# remove directory if exists
if [file exists $ip_repo_path] {
    file delete -force $ip_repo_path
}

####################################################################################################
# Create new IP peripheral core
####################################################################################################
create_peripheral ${ip_vendor} ${ip_library} ${ip_name} ${ip_version} -dir $ip_repo

set ip_core [ipx::find_open_core $ip_id]

add_peripheral_interface S_AXI -interface_mode slave -axi_type lite $ip_core
set_property VALUE 5 [ipx::get_bus_parameters WIZ_NUM_REG -of_objects [ipx::get_bus_interfaces S_AXI -of_objects $ip_core]]
generate_peripheral -driver -bfm_example_design -debug_hw_example_design $ip_core
write_peripheral $ip_core

# set_property ip_repo_paths {} [current_project]

####################################################################################################
# Open IP core for edit
####################################################################################################
set ipx_xml ${ip_repo_path}/component.xml
set ipx_project ${ip_name}_${ip_version}
set project_dir ${ip_name}_${ip_version}

# ipx::open_core ${ip_repo_path}/component.xml
ipx::edit_ip_in_project -upgrade true -name $ipx_project -directory ${projdir}/system.tmp/${ipx_project} $ipx_xml

# set additional information about IP core
set_property display_name "Fan Controller" [ipx::current_core]
set_property description "Fan Controller IP core" [ipx::current_core]
set_property company_url "http://www.braiins.com" [ipx::current_core]
set_property supported_families "zynq Production" [ipx::current_core]

set vhdl_synth_group [ipx::get_file_groups xilinx_vhdlsynthesis -of_objects [ipx::current_core]]
set vhdl_sim_group [ipx::get_file_groups xilinx_vhdlbehavioralsimulation -of_objects [ipx::current_core]]

set ip_hdl_list {}

# copy source files into IP core directory
foreach FILE $ip_hdl_files {
    file copy -force [file join $src_path $FILE] [file join $ip_repo_path hdl]
    lappend ip_hdl_list [file join hdl $FILE]
}


####################################################################################################
# Add source files into IP core, update and save IP core
####################################################################################################
foreach FILE $ip_hdl_list {
    ipx::remove_file $FILE $vhdl_synth_group
    ipx::add_file $FILE $vhdl_synth_group
    set_property type vhdlSource [ipx::get_files $FILE -of_objects $vhdl_synth_group]
    set_property library_name xil_defaultlib [ipx::get_files $FILE -of_objects $vhdl_synth_group]
}

# Copy list of synthesis group into simulation group
ipx::copy_contents_from $vhdl_synth_group $vhdl_sim_group

# remove unused files
ipx::remove_file "hdl/${ip_name}_v1_0_S_AXI.vhd" $vhdl_synth_group
ipx::remove_file "hdl/${ip_name}_v1_0_S_AXI.vhd" $vhdl_sim_group

# Update parameters and ports according to RTL sources
ipx::merge_project_changes hdl_parameters [ipx::current_core]
ipx::merge_project_changes ports [ipx::current_core]

ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project
