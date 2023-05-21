# -----------------------------------------------------------------
# synth.tcl
#
# 1/31/2012 D. W. Hawkins (dwh@caltech.edu)
#
# JTAG-to-Avalon-MM bridge Quartus synthesis script.
#
# -----------------------------------------------------------------
# Usage
# -----
#
# 1. From within Quartus, change to the project folder, and type
#
#    source scripts/synth.tcl
#
# 2. Command-line processing. Change to the project folder,
#    and type either;
#
#    a) quartus_sh -s
#       tcl> source scripts/synth.tcl
#
#    b)  quartus_sh -t scripts/synth.tcl
#
# -----------------------------------------------------------------

puts ""
puts "Synthesizing the BeMicro-SDK 'JTAG-to-Avalon-MM' design"
puts "-------------------------------------------------------"

package require ::quartus::project
package require ::quartus::flow

# -----------------------------------------------------------------
# Design paths
# -----------------------------------------------------------------

# Design directories
set top      [pwd]
set scripts  $top/scripts
set src      $top/src

# Pin assignments and device constraints
set constraints $top/../share/scripts/constraints.tcl

# -----------------------------------------------------------------
# Quartus work
# -----------------------------------------------------------------

proc quartus_version_number {} {
	global quartus
	if {[regexp {^Version (\d+[.]\d+)} $quartus(version) match result] != 1} {
		error "Error: Quartus version parsing failed"
	}
	return $result
}

global quartus
puts " - Quartus $quartus(version)"

# Version check
# * v9.1 build fails with 'Error: Part name EP4CE22F17C7 is invalid'
set qversion  [quartus_version_number]
if {$qversion < 10.0} {
	puts "Sorry, this version of Quartus II does not support the BeMicro-SDK board Cyclone IV device"
	return
}

# Quartus 11.0 contains the Verilog source, 11.1sp1 does not.
if {$qversion > 11.0} {
	set str [concat "Sorry, this version of Quartus II does not contain "\
	 "the altera_jtag_avalon_master\n   Verilog source. The script "\
	 "altera_jtag_avalon_master_hw.tcl creates the\n   component "\
	 "dynamically. Use an earlier version of Quartus, or follow "\
	 "the\n   instructions in the JTAG-to-Avalon-MM tutorial."]
	puts " "
	puts " * $str"
	puts " "
	return
}

# Local build directory
set qwork  $top/qwork

if {![file exists $qwork]} {
    puts " - Creating the Quartus work directory"
    puts "   * $qwork"
    file mkdir $qwork
}

# Create all the generated files in the work directory
cd $qwork

# -----------------------------------------------------------------
# Project
# -----------------------------------------------------------------

puts " - Create the project"

# Close any open project
# * since all the BeMicro-SDK projects are named bemicro_sdk, close
#   the current project to clear the files list. This avoids the
#   top-level files from another BeMicro-SDK project being picked
#   up if the previous project was not closed.
#
if {[is_project_open]} {
	puts "   * close the project"
	project_close
}

# Best to name the project your "top" component name.
#
#  * $quartus(project) contains the project name
#  * project_exist bemicro_sdk returns 1 only in the work directory,
#    since that is where the Quartus project file is located
#
if {[project_exists bemicro_sdk]} {
	puts "   * open the existing bemicro_sdk project"
	project_open -revision bemicro_sdk bemicro_sdk
} else {
	puts "   * create a new bemicro_sdk project"
	project_new -revision bemicro_sdk bemicro_sdk
}

# -----------------------------------------------------------------
# Design files
# -----------------------------------------------------------------

puts " - Creating the design files list"

# SystemVerilog 2005 syntax
set_global_assignment -name VERILOG_INPUT_VERSION SYSTEMVERILOG_2005

# Create a list of SystemVerilog files to build
#
set sv_files ""

# Altera IP
puts "   * Using QUARTUS_ROOTDIR = $env(QUARTUS_ROOTDIR)"
set QUARTUS_ROOTDIR $env(QUARTUS_ROOTDIR)
set ALTERA_IP_PATH  $QUARTUS_ROOTDIR/../ip/altera
set SOPC_IP_PATH    $ALTERA_IP_PATH/sopc_builder_ip

# JTAG PHY and JTAG-to-Avalon-ST components
lappend sv_files $SOPC_IP_PATH/altera_avalon_jtag_phy/altera_avalon_st_jtag_interface.v
lappend sv_files $SOPC_IP_PATH/altera_avalon_jtag_phy/altera_jtag_dc_streaming.v
lappend sv_files $SOPC_IP_PATH/altera_avalon_jtag_phy/altera_jtag_streaming.v
lappend sv_files $SOPC_IP_PATH/altera_avalon_jtag_phy/altera_jtag_sld_node.v
lappend sv_files $ALTERA_IP_PATH/avalon_st/altera_avalon_st_handshake_clock_crosser/altera_avalon_st_clock_crosser.v
lappend sv_files $ALTERA_IP_PATH/avalon_st/altera_avalon_st_pipeline_stage/altera_avalon_st_pipeline_base.v
lappend sv_files $SOPC_IP_PATH//altera_avalon_st_idle_remover/altera_avalon_st_idle_remover.v
lappend sv_files $SOPC_IP_PATH//altera_avalon_st_idle_inserter/altera_avalon_st_idle_inserter.v

# JTAG-to-Avalon-MM components
lappend sv_files $SOPC_IP_PATH/altera_avalon_sc_fifo/altera_avalon_sc_fifo.v
lappend sv_files $SOPC_IP_PATH/altera_avalon_st_packets_to_bytes/altera_avalon_st_packets_to_bytes.v
lappend sv_files $SOPC_IP_PATH/altera_avalon_st_bytes_to_packets/altera_avalon_st_bytes_to_packets.v
lappend sv_files $SOPC_IP_PATH/altera_avalon_packets_to_master/altera_avalon_packets_to_master.v
lappend sv_files $SOPC_IP_PATH/altera_jtag_avalon_master/altera_jtag_avalon_master.v
lappend sv_files $SOPC_IP_PATH/altera_jtag_avalon_master/altera_jtag_avalon_master_pli_off.v
lappend sv_files $SOPC_IP_PATH/altera_jtag_avalon_master/altera_jtag_avalon_master_pli_on.v
lappend sv_files $SOPC_IP_PATH/altera_jtag_avalon_master/altera_jtag_avalon_master_common_modules.v

# Add the design file
lappend sv_files $src/bemicro_sdk.sv

# Pass the SystemVerilog files list to Quartus
foreach sv_file $sv_files {
    set_global_assignment -name SYSTEMVERILOG_FILE $sv_file
}

# -----------------------------------------------------------------
# Design constraints
# -----------------------------------------------------------------

puts " - Applying constraints"
source $constraints
set_default_constraints

# SDC constraints
set_global_assignment -name SDC_FILE $scripts/bemicro_sdk.sdc

# SignalTapII file
set_global_assignment -name ENABLE_SIGNALTAP OFF
set_global_assignment -name USE_SIGNALTAP_FILE $scripts/bemicro_sdk.stp

# -----------------------------------------------------------------
# Process the design
# -----------------------------------------------------------------

puts " - Processing the design"

execute_flow -compile

# Use one of the following to save the settings
#project_close
export_assignments

# Return to the top directory
cd $top

puts " - Processing completed"
puts ""

