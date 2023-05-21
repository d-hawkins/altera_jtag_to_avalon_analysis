# -----------------------------------------------------------------
# sim.tcl
#
# 1/27/2012 D. W. Hawkins (dwh@caltech.edu)
#
# JTAG-to-Avalon-MM bridge testbench simulation script.
#
# -----------------------------------------------------------------
# Notes:
# ------
#
# 1. This script was tested with the following Quartus releases:
#
#       ----------------------------
#      |   Quartus   | Modelsim-ASE |
#      |-------------|--------------|
#      |   10.1      |     6.6c     |
#      |   11.0sp1   |     6.6d     |
#      |   11.1sp1   |    10.0c     |
#       ----------------------------
#
#    The QUARTUS_ROOTDIR variable can be 'reset' to a specific
#    version of Quartus by first starting that version of Quartus.
#    Then start the compatible version of Modelsim-ASE, and the
#    correct Quartus source for the JTAG-to-Avalon-ST components
#    will be used.
#
# -----------------------------------------------------------------

echo ""
echo "JTAG-to-Avalon-MM bridge simulation script"
echo "------------------------------------------"
echo ""

# -----------------------------------------------------------------
# Quartus IP directory
# -----------------------------------------------------------------
#
# NOTE: if you have multiple versions of Quartus installed,
# then you might want to edit this or the environment variable
# to force the use of a specific version.
#
echo " * Using QUARTUS_ROOTDIR = $env(QUARTUS_ROOTDIR)"

# Tcl variables
set QUARTUS_ROOTDIR $env(QUARTUS_ROOTDIR)
set ALTERA_IP_PATH  $QUARTUS_ROOTDIR/../ip/altera
set SOPC_IP_PATH    $ALTERA_IP_PATH/sopc_builder_ip

# Quartus 11.1sp1 does not have the Verilog source
if {![file exists $SOPC_IP_PATH/altera_jtag_avalon_master/altera_jtag_avalon_master.v]} {
	set str [concat "Sorry, this version of Quartus II does not contain "\
	 "the altera_jtag_avalon_master\n   Verilog source. The script "\
	 "altera_jtag_avalon_master_hw.tcl creates the\n   component "\
	 "dynamically. Use an earlier version of Quartus, or follow "\
	 "the\n   instructions in the JTAG-to-Avalon-MM tutorial."]
	echo "\n * $str\n"
	return
}

# -----------------------------------------------------------------
# Create the work directory
# -----------------------------------------------------------------
#
set mwork [pwd]/mwork
if {![file exists $mwork]} {
	echo " * Creating the Modelsim work folder; $mwork"
	vlib mwork
	vmap work mwork
}

# -----------------------------------------------------------------
# Avalon-MM files
# -----------------------------------------------------------------
#
# The list of files required to simulate the IP was determined by
# creating an SOPC System containing a JTAG-to-Avalon-MM bridge
# and a PIO component.
#
# Quartus 10.0 lists the files required for simulation as part of
# the sopc_system.v file, they are listed as includes just
# above the test_bench component (the master files are missing
# though, and we don't care about the PIO files).
#
# In Quartus 11.0, the files required for simulation are listed
# as includes in the sopc_system.qip file. Unfortunately, the
# paths in the .qip refer to *copies* in the build area, so
# you need to determine the paths to the original versions
# in the Quartus source.
#

# TODO: Make a list of files and then use Tcl to check each file exists first?

# Megafunctions and LPM components
vlog -sv $QUARTUS_ROOTDIR/eda/sim_lib/altera_mf.v
vlog -sv $QUARTUS_ROOTDIR/eda/sim_lib/220model.v
vlog -sv $QUARTUS_ROOTDIR/eda/sim_lib/sgate.v

# JTAG PHY and JTAG-to-Avalon-ST components
vlog -sv $SOPC_IP_PATH/altera_avalon_jtag_phy/altera_avalon_st_jtag_interface.v
vlog -sv $SOPC_IP_PATH/altera_avalon_jtag_phy/altera_jtag_dc_streaming.v
vlog -sv $SOPC_IP_PATH/altera_avalon_jtag_phy/altera_jtag_streaming.v
vlog -sv $SOPC_IP_PATH/altera_avalon_jtag_phy/altera_jtag_sld_node.v
vlog -sv $ALTERA_IP_PATH/avalon_st/altera_avalon_st_handshake_clock_crosser/altera_avalon_st_clock_crosser.v
vlog -sv $ALTERA_IP_PATH/avalon_st/altera_avalon_st_pipeline_stage/altera_avalon_st_pipeline_base.v
vlog -sv $SOPC_IP_PATH//altera_avalon_st_idle_remover/altera_avalon_st_idle_remover.v
vlog -sv $SOPC_IP_PATH//altera_avalon_st_idle_inserter/altera_avalon_st_idle_inserter.v

# JTAG-to-Avalon-MM components
vlog -sv  $SOPC_IP_PATH/altera_avalon_sc_fifo/altera_avalon_sc_fifo.v
vlog -sv  $SOPC_IP_PATH/altera_avalon_st_packets_to_bytes/altera_avalon_st_packets_to_bytes.v
vlog -sv  $SOPC_IP_PATH/altera_avalon_st_bytes_to_packets/altera_avalon_st_bytes_to_packets.v
vlog -sv  $SOPC_IP_PATH/altera_avalon_packets_to_master/altera_avalon_packets_to_master.v
vlog -sv  $SOPC_IP_PATH/altera_jtag_avalon_master/altera_jtag_avalon_master.v
vlog -sv  $SOPC_IP_PATH/altera_jtag_avalon_master/altera_jtag_avalon_master_pli_off.v
vlog -sv  $SOPC_IP_PATH/altera_jtag_avalon_master/altera_jtag_avalon_master_pli_on.v
vlog -sv  $SOPC_IP_PATH/altera_jtag_avalon_master/altera_jtag_avalon_master_common_modules.v

# -----------------------------------------------------------------
# Testbench
# -----------------------------------------------------------------
#
vlog -sv test/jtag_to_avalon_mm_tb.sv

echo ""
echo "JTAG-to-Avalon-MM bridge testbench procedure"
echo "--------------------------------------------"
echo ""
echo "  jtag_to_avalon_mm_tb - run the testbench"

proc jtag_to_avalon_mm_tb {} {
	vsim -novopt -t ps +nowarnTFMPC +nowarn3009 jtag_to_avalon_mm_tb
	do scripts/jtag_to_avalon_mm_tb.do
	run -a
}

