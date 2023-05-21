# -----------------------------------------------------------------
# jtag_cmds_sc.tcl
#
# 1/27/2012 D. W. Hawkins (dwh@caltech.edu)
#
# JTAG-to-Avalon-MM SystemConsole commands.
#
# These commands test the Avalon-MM 32-bit data register and the
# JTAG debug node resetrequest control.
#
# The commands can also be used to trigger SignalTap II.
#
# -----------------------------------------------------------------
# Notes
# -----
#
# 1. This script re-implements some of the SystemConsole
#    procedures using other lower-level SystemConsole services.
#    Not all procedures are reimplemented - just enough of them
#    so that the procedures can be reimplemented using quartus_stp.
#
# 2. See the SystemVerilog testbench, jtag_to_avalon_mm_tb.sv,
#    for the low-level implementation of the read/write
#    32-bit single and multiple functions.
#
# -----------------------------------------------------------------

# -----------------------------------------------------------------
# JTAG master access
# -----------------------------------------------------------------

# Open the Avalon-MM master service
proc jtag_master_open {} {
	global jtag

	# Close any open service
	if {[info exists jtag(master)] ||
		[info exists jtag(bytestream)] ||
	    [info exists jtag(sld)]} {
		jtag_close
	}

	set master_paths [get_service_paths master]
	if {[llength $master_paths] == 0} {
		puts "Sorry, no master nodes found"
		return
	}

	# Select the first master service
	set jtag(master) [lindex $master_paths 0]

	open_service master $jtag(master)
	return
}

# -----------------------------------------------------------------
# JTAG bytestream access
# -----------------------------------------------------------------

# Open the Avalon-ST bytestream service
proc jtag_bytestream_open {} {
	global jtag

	# Close any open service
	if {[info exists jtag(master)] ||
		[info exists jtag(bytestream)] ||
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
# JTAG SLD access
# -----------------------------------------------------------------
#
# Open the SLD node
proc jtag_sld_open {} {
	global jtag

	# Close any open service
	if {[info exists jtag(master)] ||
		[info exists jtag(bytestream)] ||
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
	}
	if {![info exists jtag(sld)]} {
		puts "Sorry, no SLD node with ID:132 found"
		return
	}
	open_service sld $jtag(sld)
	return
}

# -----------------------------------------------------------------
# Close the JTAG services
# -----------------------------------------------------------------
#
proc jtag_close {} {
	global jtag

	if {[info exists jtag(master)]} {
		close_service master $jtag(master)
		unset jtag(master)
	}

	if {[info exists jtag(bytestream)]} {
		close_service bytestream $jtag(bytestream)
		unset jtag(bytestream)
	}

	if {[info exists jtag(sld)]} {
		close_service sld $jtag(sld)
		unset jtag(sld)
	}

	return
}

# =================================================================
# Master commands
# =================================================================
#
# Test procedures based on the SystemConsole master service.
#
proc jtag_master_read {addr} {
	global jtag

	if {![info exists jtag(master)]} {
		jtag_master_open
	}

	# Addresses need to be 32-bit aligned
	set aligned [expr {$addr & ~0x3}]
	if {$addr != $aligned} {
		error "Addresses need to be 32-bit aligned"
	}

	# Read 32-bits
	set data [master_read_32 $jtag(master) $addr 1]
	return $data
}

proc jtag_master_write {addr data} {
	global jtag

	if {![info exists jtag(master)]} {
		jtag_master_open
	}

	# Addresses need to be 32-bit aligned
	set aligned [expr {$addr & ~0x3}]
	if {$addr != $aligned} {
		error "Addresses need to be 32-bit aligned"
	}

	# Write 32-bits
	master_write_32 $jtag(master) $addr [list $data]
	return
}

# Read a block of bytes
# * for SignalTap II tracing and data rate estimation
proc jtag_master_read_block {{len 0x100}} {
	global jtag

	if {![info exists jtag(master)]} {
		jtag_master_open
	}

	# Test register address
#	set addr 0x11223344

	# Set to zero to make it easier to trigger on the address
	# at arbitrary points mid-burst
	set addr 0

	# Read
	set start [clock clicks]
	set data [master_read_memory $jtag(master) $addr $len]
	set end [clock clicks]
	set s [expr {double($end-$start)/1000.0}]
	set s_str [format "%.2f ms" [expr {$s*1000.0}]]
	if {$s > 0} {
		set rate [expr {double($len)/$s}]
		set rate_str [format "%.2f kB/s" [expr {$rate/1024.0}]]
		puts "Transfer time: $s_str, rate: $rate_str"
	} else {
		puts "Transfer time: $s_str"
	}
	return
#	return $data
}

# Write a block of bytes
# * for SignalTap II tracing and data rate estimation
proc jtag_master_write_block {{len 0x100}} {
	global jtag

	if {![info exists jtag(master)]} {
		jtag_master_open
	}

	# Test register address
#	set addr 0x11223344

	# Set to zero to make it easier to trigger on the address
	# at arbitrary points mid-burst
	set addr 0

	# Create a block of bytes
	set bytes {}
	for {set i 0} {$i < $len} {incr i} {
		set byte [expr {0x11 * (($i + 1) % 8)}]
		lappend bytes [format 0x%.2X $byte]
	}

	# Write
	set start [clock clicks]
	master_write_memory $jtag(master) $addr $bytes
	set end [clock clicks]
	set s [expr {double($end-$start)/1000.0}]
	set s_str [format "%.2f ms" [expr {$s*1000.0}]]
	if {$s > 0} {
		set rate [expr {double($len)/$s}]
		set rate_str [format "%.2f kB/s" [expr {$rate/1024.0}]]
		puts "Transfer time: $s_str, rate: $rate_str"
	} else {
		puts "Transfer time: $s_str"
	}
	return
}

# =================================================================
# Bytestream commands
# =================================================================
#
# The jtag_bytestream_write_32 and jtag_bytestream_read_32
# procedures re-implement the master_write/read_32 functions
# using the bytestream service. SignalTap II tracing of the
# bytestream commands shows that it always uses 1kB packets,
# so the JTAG-to-Avalon-ST header is 0xFC03, even though a
# 256-byte packet (with header 0xFC00) would be sufficient.
#
# -----------------------------------------------------------------

# Response parser (one byte)
# --------------------------
#
# Parse a single byte from the bytestream response and
# update the parser global state variables (alternatively
# a parse state argument could be added and upvar used to
# access array elements within the state argument).
#
# Why so complicated? Well, the bytestream receive procedure
# can return the bytestream in blocks of none, one, or more
# bytes, so you end up needing a looped call to bytestream
# receive. This procedure here is the core of the loop, it
# accumulates bytes internally until the end-of-packet and
# final byte is received, and then returns the parsed data
# bytes, which terminates the response parser loop.
#
proc jtag_bytestream_parse_response_byte {byte} {
	global jtag
	if {![info exists jtag(response_state)]} {
		set jtag(response_state) channel
	}

	set bytes {}
	switch -exact -- $jtag(response_state) {
		channel {
#			puts "Channel (byte = $byte)"
			if {$byte == 0x7C} {
				set jtag(response_state) number
			}
		}
		number {
#			puts "Channel number (byte = $byte)"
			set jtag(response_state) sop
		}
		sop {
#			puts "Start-of-packet (byte = $byte)"
			if {$byte == 0x7A} {
				set jtag(response_state) data
			} else {
				unset jtag(response_state)
				error "bytestream response parse error!"
			}
		}
		data {
#			puts "Data (byte = $byte)"
			# Escape character?
			if {($byte == 0x4D) || ($byte == 0x7D)} {
				set jtag(response_state) esc
			} elseif {$byte == 0x7B} {
				set jtag(response_state) eop
			} else {
				if {![info exists jtag(response_bytes)]} {
					set jtag(response_bytes) $byte
				} else {
					lappend jtag(response_bytes) $byte
				}
			}
		}
		eop {
#			puts "End-of-packet (byte = $byte)"
			# Escape character?
			if {($byte == 0x4D) || ($byte == 0x7D)} {
				set jtag(response_state) esc_eop
			} else {
				if {![info exists jtag(response_bytes)]} {
					set jtag(response_bytes) $byte
				} else {
					lappend jtag(response_bytes) $byte
				}
				# Parsing is complete
				set bytes $jtag(response_bytes)
				unset jtag(response_bytes)
				unset jtag(response_state)
			}
		}
		esc {
#			puts "Escape (byte = $byte)"
			set byte [format "0x%.2X" [expr {$byte ^ 0x20}]]
			if {![info exists jtag(response_bytes)]} {
				set jtag(response_bytes) $byte
			} else {
				lappend jtag(response_bytes) $byte
			}
			set jtag(response_state) data
		}
		esc_eop {
#			puts "Escape at End-of-packet (byte = $byte)"
			set byte [format "0x%.2X" [expr {$byte ^ 0x20}]]
			if {![info exists jtag(response_bytes)]} {
				set jtag(response_bytes) $byte
			} else {
				lappend jtag(response_bytes) $byte
			}
			# Parsing is complete
			set bytes $jtag(response_bytes)
			unset jtag(response_bytes)
			unset jtag(response_state)
		}
		default {
			error "Unrecognized parse response state ($jtag(response_state))"
		}
	}
	return $bytes
}

# Response parser (all bytes)
# ---------------------------
#
# Read and parse the bytestream response
# * this procedure is called after the write or read command
#   is issued to read the bytestream until the end-of-packet
#   character and final byte is received.
# * the procedure returns the payload bytes with the header
#   (channel, channel number, and SOP) and end-of-packet
#   byte removed. Escaped bytes are also decoded.
#
proc jtag_bytestream_response {} {
	global jtag
	if {![info exists jtag(bytestream)]} {
		jtag_bytestream_open
	}

	# Receive timeout
	set timeout 1.0
	set clicks_per_second 1000
	set clicks_timeout [expr {$clicks_per_second*$timeout}]

	# Response bytes
	set bytes_rsp {}

	# Reset the timout
	set last [clock clicks]

	# Receive and parse bytes
	set length 0
	while {$length == 0} {

		# Read a block of bytes (it may also return zero bytes)
		set next [bytestream_receive $jtag(bytestream) 0x1000]

#		puts "RECEIVE: $next"

		# Stop if no data is received and the timeout is exceeded
		if {[llength $next] == 0} {
			set now [clock clicks]
			set delta [expr {$now-$last}]
			if {$delta > $clicks_timeout} {
				error "bytestream receive timeout!"
			}
		} else {
			# Valid data was received, reset the timeout
			set last [clock clicks]

			# Parse the bytes
			foreach byte $next {
				set bytes_rsp [jtag_bytestream_parse_response_byte $byte]
			}
			set length [llength $bytes_rsp]
		}
	}
	return $bytes_rsp
}

# Encode the transaction bytes in packet bytes format
#
# Byte   Value  Description
# -----  -----  ----------
#  [0]   0x7C   Channel
#  [1]   0x00   Channel number
#  [2]   0x7A   Start-of-packet
#  [X:3]        Transaction bytes with escape codes
#        0x7B   End-of-packet
#  [Y]          Last transaction byte (and escape code)
#
proc encode_bytes_to_packets {bytes} {

	set len [llength $bytes]
	set bytes_pkt {0x7C 0x00 0x7A}
	for {set i 0} {$i < $len} {incr i} {

		# Next transaction byte
		set byte [lindex $bytes $i]

		# Add the end-of-packet code before the last item
		# of data (and its escape code)
		if {$i == $len-1} {
			lappend bytes_pkt 0x7B
		}

		# Escape required?
		if {($byte >= 0x7A) && ($byte <= 0x7D)} {
			# Add an escape code
			lappend bytes_pkt 0x7D

			# Modify the byte
			set byte [expr {$byte ^ 0x20}]
		}

		# Add the byte in hex format
		lappend bytes_pkt [format "0x%.2X" $byte]
	}
	return $bytes_pkt
}

# Avalon-MM write 32-bits
# -----------------------
#
# eg., jtag_bytestream_write_32 0x11223344 0x04030201
#
proc jtag_bytestream_write_32 {addr data} {
	global jtag
	if {![info exists jtag(bytestream)]} {
		jtag_bytestream_open
	}

	# ------------------------------------
	# Transaction bytes
	# ------------------------------------
	#
	#  Byte   Value  Description
	# ------  -----  -----------
	#    [0]  0x04   Transaction code = write, with increment
	#    [1]  0x00   Reserved
	#  [3:2]  0x0004 16-bit size of each data cycle (big-endian byte order)
	#  [7:4]  32-bit address (big-endian byte order)
	# [15:8]  32-bit data (little-endian byte order)
	#
	set bytes {0x04 0x00 0x00 0x04}

	# Add the address bytes (big-endian order)
	for {set i 0} {$i < 4} {incr i} {
		lappend bytes [expr {($addr >> 8*(3-$i)) & 0xFF}]
	}

	# Add the data bytes (little-endian order)
	for {set i 0} {$i < 4} {incr i} {
		lappend bytes [expr {($data >> 8*$i) & 0xFF}]
	}

	# ------------------------------------
	# Convert to Packet bytes
	# ------------------------------------
	#
	set bytes_pkt [encode_bytes_to_packets $bytes]
	unset bytes

	# ------------------------------------
	# JTAG bytestream send
	# ------------------------------------
	#
	bytestream_send $jtag(bytestream) $bytes_pkt

	# ------------------------------------
	# Bytes-to-packet response
	# ------------------------------------
	#
	# Bytes  Value  Description
	# -----  -----  -----------
	#  [0]    0x7C  Channel
	#  [1]    0x00  Channel number
	#  [2]    0x7A  Start-of-packet
	#  [3]    0x84  Transaction code with MSB set
	#  [4]    0x00  Reserved
	#  [5]    0x00  Size[15:8]
	#  [6]    0x7B  End-of-packet
	#  [7]    0x04  Size[7:0]
	#
	# The call to jtag_bytestream_response removes the
	# channel, channel number, SOP, and EOP, leaving
	# the transaction code, reserved byte, and 16-bit
	# size bytes.
	#
	set bytes_rsp [jtag_bytestream_response]
	set len_rsp [llength $bytes_rsp]
	set bytes_exp {0x84 0x00 0x00 0x04}
	set len_exp [llength $bytes_exp]
	if {$len_rsp != $len_exp} {
		error "incorrect response byte stream!\nReceived: $bytes_rsp\nExpected: $bytes_exp"
	}
	for {set i 0} {$i < $len_exp} {incr i} {
		set byte_exp [lindex $bytes_exp $i]
		set byte_rsp [lindex $bytes_rsp $i]
		if {$byte_rsp != $byte_exp} {
			error "incorrect response byte!\nReceived: $bytes_rsp\nExpected: $bytes_exp"
		}
	}
	return
}

# Avalon-MM read 32-bits
# -----------------------
#
# eg., jtag_bytestream_read_32 0x11223344
#      => 0x04030201
#      (assuming the register had been written prior to reading)
#
proc jtag_bytestream_read_32 {addr} {
	global jtag
	if {![info exists jtag(bytestream)]} {
		jtag_bytestream_open
	}

	# ------------------------------------
	# Transaction bytes
	# ------------------------------------
	#
	#  Byte   Value  Description
	# ------  -----  -----------
	#    [0]  0x14   Transaction code = read, with increment
	#    [1]  0x00   Reserved
	#  [3:2]  0x0004 16-bit number of bytes to read (big-endian byte order)
	#  [7:4]  32-bit address (big-endian byte order)
	#
	# Header bytes
	set bytes {0x14 0x00 0x00 0x04}

	# Add the address bytes (big-endian order)
	for {set i 0} {$i < 4} {incr i} {
		lappend bytes [expr {($addr >> 8*(3-$i)) & 0xFF}]
	}

	# ------------------------------------
	# Convert to Packet bytes
	# ------------------------------------
	#
	set bytes_pkt [encode_bytes_to_packets $bytes]
	unset bytes

	# ------------------------------------
	# JTAG bytestream send
	# ------------------------------------
	#
	bytestream_send $jtag(bytestream) $bytes_pkt

	# ------------------------------------
	# Bytes-to-packet response
	# ------------------------------------
	#
	#
	# Bytes  Value  Description
	# -----  -----  -----------
	#   [0]   0x7C  Channel
	#   [1]   0x00  Channel number
	#   [2]   0x7A  Start-of-packet
	# [5:3]         Read-data bytes
	#   [6]   0x7B  End-of-packet
	#   [7]         Last data byte
	#
	# The call to jtag_bytestream_response removes the
	# channel, channel number, SOP, and EOP, leaving
	# the four data bytes.
	#
	set bytes_rsp [jtag_bytestream_response]
	set len_rsp [llength $bytes_rsp]
	if {$len_rsp != 4} {
		error "incorrect response byte stream!\nReceived: $bytes_rsp\nExpected:4-bytes"
	}

	# Convert to a 32-bit word
	set data 0
	for {set i 0} {$i < 4} {incr i} {
		set byte [lindex $bytes_rsp $i]
		set data [expr {$data | ($byte << 8*$i)}]
	}
	set data [format "0x%.8X" $data]
	return $data
}

# Avalon-MM write 32-bits multiple
# --------------------------------
#
# eg., jtag_bytestream_write_32m 0x11223344 [list 0x04030201 0x08070605]
#
proc jtag_bytestream_write_32m {addr datalist} {
	global jtag
	if {![info exists jtag(bytestream)]} {
		jtag_bytestream_open
	}

	# ------------------------------------
	# Transaction bytes
	# ------------------------------------
	#
	#  Byte   Value  Description
	# ------  -----  -----------
	#    [0]  0x04   Transaction code = write, with increment
	#    [1]  0x00   Reserved
	#  [3:2]  0xSSSS 16-bit size of each data cycle (big-endian byte order)
	#  [7:4]  32-bit address (big-endian byte order)
	# [15:8]  32-bit data (little-endian byte order)
	#
	set bytes {0x04 0x00}

	# Add the size bytes (big-endian order)
	set size [expr {4*[llength $datalist]}]
	#
	# Check that size is smaller than 16-bits
	# * large transfers need to be partitioned into blocks
	#   of 0xFFFC-bytes, i.e., 0x3FFF 32-bit words, or smaller.
	if {$size > 0xFFFF} {
		error "too many data values for a single transaction"
	}
	for {set i 0} {$i < 2} {incr i} {
		lappend bytes [expr {($size >> 8*(1-$i)) & 0xFF}]
	}

	# Add the address bytes (big-endian order)
	for {set i 0} {$i < 4} {incr i} {
		lappend bytes [expr {($addr >> 8*(3-$i)) & 0xFF}]
	}

	# Add the data bytes (little-endian order)
	foreach data $datalist {
		for {set i 0} {$i < 4} {incr i} {
			lappend bytes [expr {($data >> 8*$i) & 0xFF}]
		}
	}

	# ------------------------------------
	# Convert to Packet bytes
	# ------------------------------------
	#
	set bytes_pkt [encode_bytes_to_packets $bytes]
	unset bytes

	# ------------------------------------
	# JTAG bytestream send
	# ------------------------------------
	#
	bytestream_send $jtag(bytestream) $bytes_pkt

	# ------------------------------------
	# Bytes-to-packet response
	# ------------------------------------
	#
	# Bytes  Value  Description
	# -----  -----  -----------
	#  [0]    0x7C  Channel
	#  [1]    0x00  Channel number
	#  [2]    0x7A  Start-of-packet
	#  [3]    0x84  Transaction code with MSB set
	#  [4]    0x00  Reserved
	#  [5]    0xSS  Size[15:8]
	#  [6]    0x7B  End-of-packet
	#  [7]    0xSS  Size[7:0]
	#
	# The call to jtag_bytestream_response removes the
	# channel, channel number, SOP, and EOP, leaving
	# the transaction code, reserved byte, and 16-bit
	# size bytes.
	#
	set bytes_rsp [jtag_bytestream_response]
	set len_rsp [llength $bytes_rsp]
	set bytes_exp {0x84 0x00}
	for {set i 0} {$i < 2} {incr i} {
		lappend bytes_exp [expr {($size >> 8*(1-$i)) & 0xFF}]
	}
	set len_exp [llength $bytes_exp]
	if {$len_rsp != $len_exp} {
		error "incorrect response byte stream!\nReceived: $bytes_rsp\nExpected: $bytes_exp"
	}
	for {set i 0} {$i < $len_exp} {incr i} {
		set byte_exp [lindex $bytes_exp $i]
		set byte_rsp [lindex $bytes_rsp $i]
		if {$byte_rsp != $byte_exp} {
			error "incorrect response byte!\nReceived: $bytes_rsp\nExpected: $bytes_exp"
		}
	}
	return
}

# Avalon-MM read 32-bits multiple
# -------------------------------
#
# eg., jtag_bytestream_read_32 0x11223344 4
#      => 0x04030201 0x04030201 0x04030201 0x04030201
#      (assuming the register had been written prior to reading,
#       the same value is read since there is only one register
#       in the test design)
#
proc jtag_bytestream_read_32m {addr {datalen 1}} {
	global jtag
	if {![info exists jtag(bytestream)]} {
		jtag_bytestream_open
	}

	# ------------------------------------
	# Transaction bytes
	# ------------------------------------
	#
	#  Byte   Value  Description
	# ------  -----  -----------
	#    [0]  0x14   Transaction code = read, with increment
	#    [1]  0x00   Reserved
	#  [3:2]  0xSSSS 16-bit number of bytes to read (big-endian byte order)
	#  [7:4]  32-bit address (big-endian byte order)
	#
	# Header bytes
	set bytes {0x14 0x00}

	# Add the size bytes (big-endian order)
	set size [expr {4*$datalen}]
	#
	# Check that size is smaller than 16-bits
	# * large transfers need to be partitioned into blocks
	#   of 0xFFFC-bytes, i.e., 0x3FFF 32-bit words, or smaller.
	if {$size > 0xFFFF} {
		error "too many data values for a single transaction"
	}
	for {set i 0} {$i < 2} {incr i} {
		lappend bytes [expr {($size >> 8*(1-$i)) & 0xFF}]
	}

	# Add the address bytes (big-endian order)
	for {set i 0} {$i < 4} {incr i} {
		lappend bytes [expr {($addr >> 8*(3-$i)) & 0xFF}]
	}

	# ------------------------------------
	# Convert to Packet bytes
	# ------------------------------------
	#
	set bytes_pkt [encode_bytes_to_packets $bytes]
	unset bytes

	# ------------------------------------
	# JTAG bytestream send
	# ------------------------------------
	#
	bytestream_send $jtag(bytestream) $bytes_pkt

	# ------------------------------------
	# Bytes-to-packet response
	# ------------------------------------
	#
	#
	# Bytes  Value  Description
	# -----  -----  -----------
	#   [0]   0x7C  Channel
	#   [1]   0x00  Channel number
	#   [2]   0x7A  Start-of-packet
	# [N:3]         Read-data bytes
	# [N+1]   0x7B  End-of-packet
	# [N+2]         Last data byte
	#
	# The call to jtag_bytestream_response removes the
	# channel, channel number, SOP, and EOP, leaving
	# the 4*$datalen data bytes.
	#
	set bytes_rsp [jtag_bytestream_response]
	set len_rsp [llength $bytes_rsp]
	set len_exp [expr {4*$datalen}]
	if {$len_rsp != $len_exp} {
		error "incorrect response byte stream!\nReceived: $bytes_rsp\nExpected:$len_exp-bytes"
	}

	# Convert to multiple 32-bit words
	for {set j 0} {$j < $datalen} {incr j} {
		set data 0
		for {set i 0} {$i < 4} {incr i} {
			set byte [lindex $bytes_rsp [expr {4*$j + $i}]]
			set data [expr {$data | ($byte << 8*$i)}]
		}
		set data [format "0x%.8X" $data]
		lappend datalist $data
	}
	return $datalist
}


# =================================================================
# SLD commands
# =================================================================
#
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