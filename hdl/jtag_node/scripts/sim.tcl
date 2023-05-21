# -----------------------------------------------------------------
# sim.tcl
#
# 1/27/2012 D. W. Hawkins (dwh@caltech.edu)
#
# JTAG node testbench simulation script.
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
echo "JTAG node simulation script"
echo "---------------------------"
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
# JTAG node files
# -----------------------------------------------------------------
#

# JTAG node
vlog -sv $SOPC_IP_PATH/altera_avalon_jtag_phy/altera_jtag_sld_node.v

# -----------------------------------------------------------------
# Testbench
# -----------------------------------------------------------------
#
vlog -sv test/jtag_node_tb.sv

echo ""
echo "JTAG node testbench procedure"
echo "--------------------------------------------"
echo ""
echo "  jtag_node_tb - run the testbench"

proc jtag_node_tb {} {
	vsim -novopt -t ps jtag_node_tb
	do scripts/jtag_node_tb.do
	run -a
}

