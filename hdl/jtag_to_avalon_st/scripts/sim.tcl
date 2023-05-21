# -----------------------------------------------------------------
# sim.tcl
#
# 1/27/2012 D. W. Hawkins (dwh@caltech.edu)
#
# JTAG-to-Avalon-ST bridge testbench simulation script.
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
echo "JTAG-to-Avalon-ST bridge simulation script"
echo "------------------------------------------"
echo ""

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

# -----------------------------------------------------------------
# Avalon-ST files
# -----------------------------------------------------------------
#
# The list of files required to simulate the IP was determined by
# creating an SOPC System containing only a JTAG-to-Avalon-ST
# bridge. Connect the Avalon-ST source to the sink, and then use
# ctrl-Generate to force the generation of the system Verilog
# file sopc_system.v. The files required for simulation are listed
# as includes in the generated verilog file (above the test_bench
# component).
#

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

# -----------------------------------------------------------------
# Testbench
# -----------------------------------------------------------------
#
vlog -sv test/jtag_to_avalon_st_tb.sv

echo ""
echo "JTAG-to-Avalon-ST bridge testbench procedure"
echo "--------------------------------------------"
echo ""
echo "  jtag_to_avalon_st_tb - run the testbench"

proc jtag_to_avalon_st_tb {} {
	vsim -novopt -t ps +nowarnTFMPC +nowarn3009 jtag_to_avalon_st_tb
	do scripts/jtag_to_avalon_st_tb.do
	run -a
}

