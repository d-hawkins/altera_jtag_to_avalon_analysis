# -----------------------------------------------------------------
# jtag_cmds_sc.tcl
#
# 1/27/2012 D. W. Hawkins (dwh@caltech.edu)
#
# JTAG node SystemConsole commands.
#
# These commands test the JTAG 3-bit IR and the 8-bit data register
# (located in the TDI->TDO path).
#
# The commands can also be used to trigger SignalTap II.
#
# -----------------------------------------------------------------
# SignalTap II Trigger Example
# ----------------------------
#
# 1. Use SystemConsole to clear the IR
#    -> jtag_sld_vir 0
#
# 2. Close the SystemConsole JTAG connection
#    -> jtag_close
#
# 3. Start SignalTap and setup a trigger on IR_IN = 5. Do not arm
#    SignalTap just yet. Set the trigger position as post-trigger
#    (since all the JTAG activity occurs before the trigger).
#
# 4. Open the SystemConsole JTAG connection
#    -> jtag_open
#
# 5. Arm SignalTap.
#
# 6. Use SystemConsole to trigger SignalTap
#    -> jtag_sld_vir 5
#
# The order in which SystemConsole and SignalTap II access the
# JTAG interface is important. If you do not follow the above
# sequence, one of the JTAG GUIs will appear to hang and the
# processes need to be killed.
#
# -----------------------------------------------------------------
# Notes:
# ------
#
# 1. SystemConsole interrogates the JTAG chain when it starts.
#    This interrogation causes the IR to change to the value 3
#    (this is visible on the IR LEDs, i.e., LED[6:4] = 3).
#
# -----------------------------------------------------------------

# -----------------------------------------------------------------
# JTAG chain access
# -----------------------------------------------------------------

# Open the SLD node
proc jtag_open {} {
	global jtag

	# Close any open service
	if {[info exists jtag(sld)]} {
		jtag_close
	}

	set sld_paths [get_service_paths sld]
	if {[llength $sld_paths] == 0} {
		puts "Sorry, no SLD nodes found"
		return
	}

	# Quartus lists SignalTap instances under SLD services,
	# so make sure the SLD node ID is 132
	# (the SignalTap node ID is 0).
	foreach sld $sld_paths {

		# Quartus 10.1sp1, 11.0sp1 string format:
		#
		# % get_service_paths sld
		# {/connections/USB-Blaster on localhost [USB-0]/EP3C25|EP4CE22@1/[MFG:110 ID:0 INST:0 VER:6]}
		# {/connections/USB-Blaster on localhost [USB-0]/EP3C25|EP4CE22@1/[MFG:110 ID:132 INST:0 VER:1]}
		#
		if {[regexp {ID:132} $sld match result] == 1} {
			set jtag(sld) $sld
			break
		}

		# Quartus 11.1sp1 string format:
		#
		# % get_service_paths sld
		# {/devices/EP3C25|EP4CE22@1#USB-0/(link)/JTAG/(110:0 v6 #0)}
		# {/devices/EP3C25|EP4CE22@1#USB-0/(link)/JTAG/(110:132 v1 #0)}
		#
		if {[regexp {110:132} $sld match result] == 1} {
			set jtag(sld) $sld
			break
		}
	}
	if {![info exists jtag(sld)]} {
		puts "Sorry, no SLD node with ID:132 found"
		return
	}
	open_service sld $jtag(sld)
	return
}

# Close the SLD node
proc jtag_close {} {
	global jtag
	if {[info exists jtag(sld)]} {
		close_service sld $jtag(sld)
		unset jtag(sld)
	}
	return
}

# -----------------------------------------------------------------
# Virtual IR access
# -----------------------------------------------------------------

# Write to the 3-bit IR register and update the LEDs, read the
# 3-bit IR response (which is connected to the switches)
proc jtag_sld_vir {val} {
	global jtag
	if {![info exists jtag(sld)]} {
		jtag_open
	}
	set val [expr {$val & 0x7}]
	sld_lock $jtag(sld) 1
	set ret [sld_access_ir $jtag(sld) $val 1000]
	sld_unlock $jtag(sld)
	return $ret
}

# Test the JTAG 3-bit IR register
proc jtag_sld_vir_count {{len 0x10}} {

	puts "IR LED count (from 0 to [expr {$len - 1}]) and switch readback"
	for {set i 0} {$i < $len} {incr i} {
		set ret [jtag_sld_vir $i]
		puts " * LED\[6:4\] = $i, SW\[2:1\] = $ret"
		after 1000
	}
	return
}

# -----------------------------------------------------------------
# Virtual DR access
# -----------------------------------------------------------------

# Data register write
proc jtag_sld_data_write {val} {
	global jtag
	if {![info exists jtag(sld)]} {
		jtag_open
	}
	set val [expr {$val & 0xFF}]

	# Set IR = 0 and write the 8-bit data
	sld_lock $jtag(sld) 1

	# Use the two low-level commands inside the lock so that
	# SignalTap II sees both transactions
	sld_access_ir $jtag(sld) 0 1000
	sld_access_dr $jtag(sld) 8 1000 $val

	sld_unlock $jtag(sld)
	return
}

# Data register read
proc jtag_sld_data_read {} {
	global jtag
	if {![info exists jtag(sld)]} {
		jtag_open
	}

	# Set IR = 1 and read the 8-bit data (write zeros)
	sld_lock $jtag(sld) 1

	# Use the two low-level commands inside the lock so that
	# SignalTap II sees both transactions
	sld_access_ir $jtag(sld) 1 1000
	set ret [sld_access_dr $jtag(sld) 8 1000 0]

	sld_unlock $jtag(sld)
	return $ret
}

# Switch state read
proc jtag_sld_sw_read {} {
	global jtag
	if {![info exists jtag(sld)]} {
		jtag_open
	}

	# Set IR = 2
	jtag_sld_vir 2

	# Read the 8-bit data (write zeros)
	sld_lock $jtag(sld) 1
	set ret [sld_access_dr $jtag(sld) 8 1000 0]
	sld_unlock $jtag(sld)
	return $ret
}

# Generate a count on the LEDs using the data register.
# Read the data register and the switch state register.
proc jtag_sld_data_count {{len 0x10}} {

	puts "Data register LED count (from 0 to [expr {$len - 1}]) and readback"
	for {set i 0} {$i < $len} {incr i} {
		jtag_sld_data_write $i
		set data [jtag_sld_data_read]
		set sw [jtag_sld_sw_read]
		puts " * LED\[3:0\] = [format 0x%.2X $i], data\[7:0\] = [format 0x%.2X $data], SW\[2:1\] = $sw"
		after 1000
	}
	return
}
