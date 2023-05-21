# -----------------------------------------------------------------
# jtag_cmds_sc.tcl
#
# 1/27/2012 D. W. Hawkins (dwh@caltech.edu)
#
# JTAG-to-Avalon-ST SystemConsole commands.
#
# These commands test the Avalon-ST 8-bit data register and the
# JTAG debug node resetrequest control.
#
# The commands can also be used to trigger SignalTap II.
#
# For example, you can configure SignalTap to trigger on the
# source valid flag, and then use the repeat trigger to track
# the incrementing count implemented by jtag_bytestream_count.
#
# You can also trigger on the JTAG data from the host, eg.,
# trigger on the ESCAPE or IDLE codes to view the host-to-JTAG
# protocol.
#
# -----------------------------------------------------------------

# -----------------------------------------------------------------
# JTAG-to-Avalon-ST access
# -----------------------------------------------------------------

# Open the Avalon-ST bytestream service
proc jtag_bytestream_open {} {
	global jtag

	# Close any open service
	if {[info exists jtag(bytestream)] ||
	    [info exists jtag(debug)] ||
	    [info exists jtag(sld)]} {
		jtag_close
	}

	set bytestream_paths [get_service_paths bytestream]
	if {[llength $bytestream_paths] == 0} {
		puts "Sorry, no bytestream nodes found"
		return
	}

	# Select the first bytestream service
	set jtag(bytestream) [lindex $bytestream_paths 0]

	open_service bytestream $jtag(bytestream)
	return
}

# -----------------------------------------------------------------
# JTAG debug access
# -----------------------------------------------------------------
#
# Use these procedures to open/close the JTAG debug node, since
# it first checks for an open bytestream node. The standard
# Quartus JTAG debug procedures can then be used with the
# path argument set to jtag(debug).
#
# eg., jtag_debug_open
#      jtag_debug_reset_system $jtag(debug)
#      jtag_debug_close
#
# SignalTap II shows that this command pulses resetrequest
# (the resetrequest LED blinks for around 1 second)
#
# The state of cpu_rstN can be read via
#
#      jtag_debug_sample_reset $jtag(debug)
#
# Its normally 1, and if you press the 'Reset' button, it becomes
# zero.
#
# The presence of the clock can be tested via
#
#      jtag_debug_sense_clock $jtag(debug)
#
# which returns 1 to indicate the clock is toggling.
#
# See p1479 of the Quartus v11.1.0 handbook for the jtag_debug
# procedures.
#

# Open the jtag_debug service
proc jtag_debug_open {} {
	global jtag

	# Close any open service
	if {[info exists jtag(bytestream)] ||
	    [info exists jtag(debug)] ||
	    [info exists jtag(sld)]} {
		jtag_close
	}

	set jtag_debug_paths [get_service_paths jtag_debug]
	if {[llength $jtag_debug_paths] == 0} {
		puts "Sorry, no jtag_debug nodes found"
		return
	}

	# Select the first jtag_debug service
	set jtag(debug) [lindex $jtag_debug_paths 0]

	open_service jtag_debug $jtag(debug)
	return
}

# -----------------------------------------------------------------
# JTAG SLD access
# -----------------------------------------------------------------
#
# Open the SLD node
proc jtag_sld_open {} {
	global jtag

	# Close any open service
	if {[info exists jtag(bytestream)] ||
	    [info exists jtag(debug)] ||
	    [info exists jtag(sld)]} {
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

		# Quartus 12.1sp1 string format:
		#
		# % get_service_paths sld
		# {/devices/EP3C25|EP4CE22@1#USB-0/(link)/JTAG/(110:0 v6 #0)}
		# /devices/EP3C25|EP4CE22@1#USB-0/(link)/JTAG/jtag_phy_0
		#
		if {[regexp {jtag_phy} $sld match result] == 1} {
			set jtag(sld) $sld
			break
		}
	}
	if {![info exists jtag(sld)]} {
		puts "Sorry, no SLD node found"
		return
	}
	open_service sld $jtag(sld)
	return
}

# -----------------------------------------------------------------
# Close the Avalon-ST bytestream or JTAG debug service
# -----------------------------------------------------------------
#
proc jtag_close {} {
	global jtag

	if {[info exists jtag(bytestream)]} {
		close_service bytestream $jtag(bytestream)
		unset jtag(bytestream)
	}

	if {[info exists jtag(debug)]} {
		close_service jtag_debug $jtag(debug)
		unset jtag(debug)
	}

	if {[info exists jtag(sld)]} {
		close_service sld $jtag(sld)
		unset jtag(sld)
	}

	return
}

# =================================================================
# JTAG debug commands
# =================================================================
#
# Just use jtag_sld_open and then the SystemConsole commands
# with an argument of $jtag(sld).

# =================================================================
# Bytestream commands
# =================================================================
#
proc jtag_bytestream_write {val} {
	global jtag

	if {![info exists jtag(bytestream)]} {
		jtag_bytestream_open
	}
	set val [expr {$val & 0xFF}]
	bytestream_send $jtag(bytestream) [list $val]
	return
}

proc jtag_bytestream_read {} {
	global jtag

	if {![info exists jtag(bytestream)]} {
		jtag_bytestream_open
	}
	set ret [bytestream_receive $jtag(bytestream) 1]
	return $ret
}

# Write to the Avalon-ST register, and read the loopback value.
# The loopback data is the previous write data (or zero at the
# start).
#
proc jtag_bytestream_count {{len 0x10}} {

	puts "Avalon-ST data LED count (from 0 to [expr {$len - 1}])"
	for {set i 0} {$i < $len} {incr i} {
		jtag_bytestream_write $i
		set data [jtag_bytestream_read]
		puts " * LED\[5:0\] = [format 0x%.2X $i], data\[7:0\] = [format 0x%.2X $data]"
		after 1000
	}
	return

}

# Send a series of ASCII values through the bytestream
#
# * SignalTap can trace the Avalon-ST output to see each of
#   these bytes on the Avalon-ST interface.
#
# * SignalTap can also be used to trace the host-to-JTAG
#   interface which includes the IDLE code (0x4A) and the
#   ESCAPE code (0x4D). These codes just happen to be valid
#   ASCII codes, i.e., 0x4A = J, 0x4D = M, so if you send
#   the string "JUMP", you will see the Avalon-ST bytes
#
#   "JUMP\r\n" =>  0x4A 0x55 0x4D 0x50 0x0D 0x0A
#
#   but internally from the host to JTAG you will see the
#   bytes
#
#   0x4D 0x6A 0x55 0x4D 0x6D 0x50 0x0D 0x0A
#
#   where the "J" and the "M" have an ESCAPE code followed
#   by the XOR of the data with 0x20.
#
proc jtag_bytestream_string {str} {
	global jtag

	if {![info exists jtag(bytestream)]} {
		jtag_bytestream_open
	}

	# Flush any characters in the receive bytestream
	set len 1
	while {$len > 0} {
		set data [bytestream_receive $jtag(bytestream) 100]
		set len [llength $data]
	}

	# Convert the string to a list of hex values
	set bytes {}
	set len [string length $str]
	for {set i 0} {$i < $len} {incr i} {
		set char [string index $str $i]
  		if {[scan $char %c byte] != 1} {
  			error "Error: character-to-ASCII conversion failed!"
  		}
		lappend bytes [format "0x%.2X" $byte]
	}
	puts "Send the bytes: $bytes"

	# Send the bytes
	if {1} {
		# In a single transaction
		bytestream_send $jtag(bytestream) $bytes

	} else {
		# Send the bytes slowly (to test the receive logic)
		for {set i 0} {$i < $len} {incr i} {
			set byte_next [lindex $bytes $i]
			bytestream_send $jtag(bytestream) $byte_next
			puts "Send byte: $byte_next"
			after 100
		}
	}

	# Receive the loopback response
	# * bytestream_receive responds with an empty packet
	#   several times before valid data is returned
	# * the bytes can be returned via multiple receives
	#
	set len_left $len
	set bytes_rsp {}
	while {$len_left > 0} {
		set bytes_next [bytestream_receive $jtag(bytestream) $len_left]
#		puts "Received bytes: $bytes_next"
		set len_next [llength $bytes_next]
		if {$len_next > 0} {
			set bytes_rsp [concat $bytes_rsp $bytes_next]
			set len_left  [expr {$len_left - $len_next}]
		}
	}

	# Check the bytes received match those transmitted
	for {set i 0} {$i < $len} {incr i} {
		set byte     [lindex $bytes $i]
		set byte_rsp [lindex $bytes_rsp $i]
		if {$byte_rsp != $byte} {
			error "Error: received incorrect byte $byte_rsp, but expected $byte!"
		}
	}
	puts "Received the correct echo bytes"
	return
}

# Send a block of data over the bytestream interface in one
# chunk. The internal bytestream interface transfers data
# in blocks of 1024-bytes.
#
# The purpose of this procedure is to send blocks of data to
# see whether the bytestream header changes for large blocks.
# A unique code is used as the first and last byte so that
# SignalTap II can use these bytes as a trigger.
#
# The data is formatted such that;
# * the first byte is 0x11 (call this the start-of-packet)
# * the last byte is  0x22 (call this the end-of-packet)
# * the payload bytes are alternating 0xAA 0x55 codes
#
# This format avoids sending the IDLE (0x4A) and ESCAPE (0x4D)
# codes (which would need to be escaped correctly).
#
proc jtag_bytestream_block {{block_len 0x100} {check_response 1}} {
	global jtag

	if {![info exists jtag(bytestream)]} {
		jtag_bytestream_open
	}

	# Flush any characters in the receive bytestream
	set len 1
	while {$len > 0} {
		set data [bytestream_receive $jtag(bytestream) 100]
		set len [llength $data]
	}

	if {$block_len < 2} {
		error "The block length needs to be 2 or greater"
	}

	# Create the data bytes
	#
	# Start-of-packet
	set bytes 0x11
	set len [expr {$block_len - 2}]
	for {set i 0} {$i < $len} {incr i} {
		if {[expr {$i & 1}]} {
			lappend bytes 0xAA
		} else {
			lappend bytes 0x55
		}
	}
	# End-of-packet
	lappend bytes 0x22

	# Check the packet length
	set len [llength $bytes]
	if {$len != $block_len} {
		error "Error: the byte block length is $len-bytes!"
	}

	# Send the bytes
	puts "Send a block of [format %d $block_len]-bytes"
	bytestream_send $jtag(bytestream) $bytes

	# Avalon-ST loopback response check
	if {$check_response != 1} {
		return
	}

	# Receive the loopback response
	# * bytestream_receive responds with an empty packet
	#   several times before valid data is returned
	# * the bytes can be returned via multiple receives
	#
	set len      $block_len
	set len_left $block_len
	set bytes_rsp {}
	while {$len_left > 0} {
		set bytes_next [bytestream_receive $jtag(bytestream) $len_left]
#		puts "Received bytes: $bytes_next"
		set len_next [llength $bytes_next]
		if {$len_next > 0} {
			set bytes_rsp [concat $bytes_rsp $bytes_next]
			set len_left  [expr {$len_left - $len_next}]
		}
	}

	# Check the bytes received match those transmitted
	for {set i 0} {$i < $len} {incr i} {
		set byte     [lindex $bytes $i]
		set byte_rsp [lindex $bytes_rsp $i]
		if {$byte_rsp != $byte} {
			error "Error: received incorrect byte $byte_rsp, but expected $byte!"
		}
	}
	puts "Received the correct echo bytes"
	return
}

# =================================================================
# SLD commands
# =================================================================
#
# Reimplement the bytestream send/receive functions using the
# low-level VIR/VDR commands.
#
# -----------------------------------------------------------------
# Bytestream send/receive
# -----------------------------------------------------------------
#
# Send a block of fixed pattern data
proc jtag_sld_bytestream {{block_len 0x400}} {
	global jtag

	if {![info exists jtag(sld)]} {
		jtag_sld_open
	}

	# Maximum block for a single transaction
	set max_len [expr {256*1024}]
	if {$block_len > $max_len} {
		error "Sorry, block length must be less than 256kB"
	}

	# Scan length (units of 256-bytes)
	set scan_len [expr {int(ceil(double($block_len)/256.0))-1}]
	set bytes_len [expr {256*($scan_len+1)}]

	# Create the payload bytes
	#
	# Start-of-packet code (for SignalTap II triggering)
	set bytes 0x11

	# Alternating 0x55 0xAA pattern
	for {set i 0} {$i < $bytes_len/2-1} {incr i} {
		set bytes [concat $bytes [list 0x55 0xAA]]
	}
	# End-of-packet code (for SignalTap II triggering)
	set bytes [concat $bytes 0x22]

	# 16-bit header
	# * read_data_length = write_data_length = 7 (use scan_length)
	set header [expr {(7<<13) | (7<<10) | ($scan_len & 0x3FF)}]

	# Add the header
	set header_lsb [format "0x%.2X" [expr {$header & 0xFF}]]
	set header_msb [format "0x%.2X" [expr {($header >> 8) & 0xFF}]]
	set bytes [concat $header_lsb $header_msb $bytes]

	# Total number of bytes/bits (for Virtual Shift-DR)
	set len [llength $bytes]
	set bits [expr {8*$len}]

	puts "Transmitted $len-bytes ($bytes_len-bytes payload)"

	# Acquire JTAG
	sld_lock $jtag(sld) 1

	# Virtual IR = 0 (DATA mode)
	sld_access_ir $jtag(sld) 0 1000

	# Virtual DR data bytes
	set ret [sld_access_dr $jtag(sld) $bits 1000 $bytes]

	# Release JTAG
	sld_unlock $jtag(sld)

	# The return response is;
	# * 16-bit read response header
	#   LSB of the first byte = read data available indicator
	# * followed by IDLE (0x4A) or data bytes.
	#
	# For the non-loopback design, IDLE bytes are received.
	# For the loopback design, two IDLE bytes followed by
	# data bytes are returned, and then for the next stream,
	# the data available flag is set, and the last two bytes
	# from the previous loopback are received.
	#
	# No bytes are lost.
	#
	puts "Return response = $ret"

	set header [expr {[lindex $ret 0] | ([lindex $ret 1] << 8)}]
	if {$header == 0} {
		puts "No read data available"
	} elseif {$header == 1} {
		puts "Read data available"
	} else {
		puts "Error: invalid header response"
	}

	# Some simple response parsing
	if {$header == 1} {
		set index 2
		set byte [lindex $ret $index]
		while {$byte != 0x11} {
			if {$byte == 0x4A} {
				puts "IDLE code: $byte"
			} elseif {$byte == 0x22} {
				puts "End-of-packet detected: $byte"
			} else {
				puts "Old read data byte: $byte"
			}
			incr index
			set byte [lindex $ret $index]
		}
		puts "Start-of-packet detected: $byte"

		# Now check for alternating 0x55 0xAA ...
	}

	# else check for IDLE codes

	return
}

# -----------------------------------------------------------------
# Bytestream string send/receive
# -----------------------------------------------------------------
#
# Send a string
proc jtag_sld_bytestream_string {str} {
	global jtag

	if {![info exists jtag(sld)]} {
		jtag_sld_open
	}

	# Convert the string to a list of hex values
	set bytes {}
	set len [string length $str]
	for {set i 0} {$i < $len} {incr i} {
		set char [string index $str $i]
  		if {[scan $char %c byte] != 1} {
  			error "Error: character-to-ASCII conversion failed!"
  		}
		lappend bytes [format "0x%.2X" $byte]
	}

	# Number of bytes in the string
	set str_len [llength $bytes]

	# Scan length (units of 256-bytes)
	set scan_len [expr {int(ceil(double($str_len)/256.0))-1}]
	set bytes_len [expr {256*($scan_len+1)}]

	# Pad with IDLE bytes
	for {set i $str_len} {$i < $bytes_len} {incr i} {
		lappend bytes 0x4A
	}

	# 16-bit header
	# * read_data_length = write_data_length = 7 (use scan_length)
	set header [expr {(7<<13) | (7<<10) | ($scan_len & 0x3FF)}]

	# Add the header
	set header_lsb [format "0x%.2X" [expr {$header & 0xFF}]]
	set header_msb [format "0x%.2X" [expr {($header >> 8) & 0xFF}]]
	set bytes [concat $header_lsb $header_msb $bytes]

	# Add garbage byte(s) to the start
	set bytes [concat [list 0x55 0x55] $bytes]

	# Set the offset to skip the garbage byte(s)
	jtag_sld_control 16 0

	# Total number of bytes/bits (for Virtual Shift-DR)
	set len [llength $bytes]
	set bits [expr {8*$len}]

	puts "Transmitted $len-bytes ($bytes_len-bytes payload)"

	# Acquire JTAG
	sld_lock $jtag(sld) 1

	# Virtual IR = 0 (DATA mode)
	sld_access_ir $jtag(sld) 0 1000

	# Virtual DR data bytes
	set ret [sld_access_dr $jtag(sld) $bits 1000 $bytes]

	# Release JTAG
	sld_unlock $jtag(sld)

	# The return response is;
	# * 16-bit read response header
	#   LSB of the first byte = read data available indicator
	# * followed by IDLE (0x4A) or data bytes.
	#
	puts "Return response = $ret"
	set header [expr {[lindex $ret 0] | ([lindex $ret 1] << 8)}]
	if {$header == 0} {
		puts "No read data available"
	} elseif {$header == 1} {
		puts "Read data available"
	} else {
		puts "Error: invalid header response"
	}

	return
}

# -----------------------------------------------------------------
# Debug register status
# -----------------------------------------------------------------
#
proc jtag_sld_debug {} {
	global jtag

	if {![info exists jtag(sld)]} {
		jtag_sld_open
	}

	# Acquire JTAG
	sld_lock $jtag(sld) 1

	# Virtual IR = 2 (DEBUG mode)
	sld_access_ir $jtag(sld) 2 1000

	# Virtual DR (3-bit read)
	set ret [sld_access_dr $jtag(sld) 3 1000 0]

	# There is an error in the dr_debug register logic, in that
	# it uses virtual_state_udr, instead of virtual_state_e1dr,
	# to pulse the clock sense reset line. Since the FSM ends in
	# udr, there is no TCK edge to pulse reset. Use a VIR
	# transaction to generate TCK activity.

	# Virtual IR = 0 (DATA mode)
	sld_access_ir $jtag(sld) 0 1000

	# Release JTAG
	sld_unlock $jtag(sld)

	set bit [expr {$ret & 1}]
	puts "reset_to_sample_sync = $bit"
	set bit [expr {($ret >> 1) & 1}]
	puts "clock_to_sample_div2_sync = $bit"
	set bit [expr {($ret >> 2) & 1}]
	puts "clock_sensor_sync = $bit"

	return
}

# -----------------------------------------------------------------
# Info register status
# -----------------------------------------------------------------
#
proc jtag_sld_info {} {
	global jtag

	if {![info exists jtag(sld)]} {
		jtag_sld_open
	}

	# Acquire JTAG
	sld_lock $jtag(sld) 1

	# Virtual IR = 3 (INFO mode)
	sld_access_ir $jtag(sld) 3 1000

	# Virtual DR (11-bit read)
	set bytes [list 0x00 0x00]
	set ret [sld_access_dr $jtag(sld) 11 1000 $bytes]

	# Release JTAG
	sld_unlock $jtag(sld)

	set ret [expr {[lindex $ret 0] | ([lindex $ret 1] << 8)}]
	set bits [expr {$ret & 0xF}]
	puts "downstream_encoded_size\[3:0\] = $bits"
	set bits [expr {($ret >> 4) & 0xF}]
	puts "upstream_encoded_size\[3:0\] = $bits"
	set bits [expr {($ret >> 8) & 0x7}]
	if {$bits == 0} {
		puts "purpose\[2:0\] = $bits (JTAG PHY)"
	} elseif {$bits == 1} {
		puts "purpose\[2:0\] = $bits (JTAG-to-Avalon-MM master)"
	}

	return
}

# -----------------------------------------------------------------
# Resetrequest control
# -----------------------------------------------------------------
#
# This can be used to set resetrequest high and turn on an LED,
# or low and turn off an LED.
#
proc jtag_sld_resetrequest {{val 1}} {
	global jtag

	if {![info exists jtag(sld)]} {
		jtag_sld_open
	}

	# Control bytes (9-bit register)
	set bits 9
	if {$val == 1} {
		# Set bit 9
		set bytes [list 0x00 0x01]
	} else {
		set bytes [list 0x00 0x00]
	}

	# Acquire JTAG
	sld_lock $jtag(sld) 1

	# Virtual IR = 4 (CONTROL mode)
	sld_access_ir $jtag(sld) 4 1000

	# Virtual DR data bytes
	sld_access_dr $jtag(sld) $bits 1000 $bytes

	# There is an error in the dr_control register logic, in that
	# it uses virtual_state_udr, instead of virtual_state_e1dr,
	# to latch the new value. Since the FSM ends in udr, there
	# is no TCK edge to latch the new value. Use a VIR transaction
	# to generate TCK activity.

	# Virtual IR = 0 (DATA mode)
	sld_access_ir $jtag(sld) 0 1000

	# Release JTAG
	sld_unlock $jtag(sld)

	return
}

# -----------------------------------------------------------------
# Offset control
# -----------------------------------------------------------------
#
# The 9-bit CONTROL register controls the 8-bit offset value and
# the state of resetrequest.
#
# The LED connected to reset request can be toggled via
#
#   jtag_sld_control 0 1
#   jtag_sld_control 0 0
#
proc jtag_sld_control {{offset 0} {reset 1}} {
	global jtag

	if {![info exists jtag(sld)]} {
		jtag_sld_open
	}

	# Make sure the values are within their bit-widths
	set offset [expr {$offset & 0xFF}]
	set reset  [expr {$reset & 1}]

	# Control bytes (9-bit register)
	set bits 9
	set bytes [list $offset $reset]

	# Acquire JTAG
	sld_lock $jtag(sld) 1

	# Virtual IR = 4 (CONTROL mode)
	sld_access_ir $jtag(sld) 4 1000

	# Virtual DR data bytes
	sld_access_dr $jtag(sld) $bits 1000 $bytes

	# There is an error in the dr_control register logic, in that
	# it uses virtual_state_udr, instead of virtual_state_e1dr,
	# to latch the new value. Since the FSM ends in udr, there
	# is no TCK edge to latch the new value. Use a VIR transaction
	# to generate TCK activity.

	# Virtual IR = 0 (DATA mode)
	sld_access_ir $jtag(sld) 0 1000

	# Release JTAG
	sld_unlock $jtag(sld)

	return
}
