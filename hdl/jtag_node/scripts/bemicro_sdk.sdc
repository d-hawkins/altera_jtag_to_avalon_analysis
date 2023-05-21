# bemicro_sdk.sdc
#
# 1/27/2012 D. W. Hawkins (dwh@caltech.edu)
#
# Quartus II synthesis TimeQuest SDC timing constraints.
#
# -----------------------------------------------------------------
# Notes:
# ------
#
# 1. The results of this script can be analyzed using the
#    TimeQuest GUI
#
#    a) From Quartus, select Tools->TimeQuest Timing Analyzer
#    b) In TimeQuest, Netlist->Create Timing Netlist, Ok
#    c) Run any of the analysis tasks
#       eg. 'Check Timing' and 'Report Unconstrained Paths'
#       show the design is constrained.
#
# -----------------------------------------------------------------

# -----------------------------------------------------------------
# Clock
# -----------------------------------------------------------------
#
# 50MHz clock
# -----------
# * 20ns period
# * Can be used by SignalTap II even if no logic uses it
#
set ports [get_ports -nowarn {clkin_50MHz}]
if {[get_collection_size $ports] == 1} {
	set clkin_50MHz_period 20
	set name clkin_50MHz
	puts "  ==> BeMicro-SDK: constrain clock $name"
	create_clock                    \
		-period $clkin_50MHz_period \
		-name $name [get_ports $name]
	set_clock_groups -exclusive -group $name
}

# Derive the clock uncertainty parameter (for JTAG clock)
derive_clock_uncertainty

# -----------------------------------------------------------------
# Cut timing paths
# -----------------------------------------------------------------
#
# The timing for the I/Os in this design is arbitrary, so cut all
# paths to the I/Os, even the ones that are used in the design,
# i.e., reset and the LEDs.
#

# External asynchronous reset
set_false_path -from [get_ports cpu_rstN] -to *

# LED output path
set_false_path -from * -to [get_ports led*]

