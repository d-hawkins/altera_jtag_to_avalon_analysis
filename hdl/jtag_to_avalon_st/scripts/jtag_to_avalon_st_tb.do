onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /jtag_to_avalon_st_tb/test_number
add wave -noupdate -divider {Avalon-ST interface}
add wave -noupdate /jtag_to_avalon_st_tb/clk
add wave -noupdate /jtag_to_avalon_st_tb/reset_n
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/source_data
add wave -noupdate /jtag_to_avalon_st_tb/source_ready
add wave -noupdate /jtag_to_avalon_st_tb/source_valid
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/sink_data
add wave -noupdate /jtag_to_avalon_st_tb/sink_valid
add wave -noupdate /jtag_to_avalon_st_tb/sink_ready
add wave -noupdate /jtag_to_avalon_st_tb/u1/resetrequest
add wave -noupdate -divider {Internal signals}
add wave -noupdate -divider {JTAG encoded bytestreams}
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/idle_remover_sink_valid
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/idle_remover_sink_data
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/idle_inserter_source_ready
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/idle_inserter_source_data
add wave -noupdate -divider {JTAG decoded bytestreams}
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/idle_remover_source_valid
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/idle_remover_source_data
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/idle_inserter_sink_valid
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/idle_inserter_sink_data
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/idle_inserter_sink_ready
add wave -noupdate -divider JTAG
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/tck
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/tdi
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/tdo
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/node/virtual_state_cdr
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/node/virtual_state_sdr
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/node/virtual_state_e1dr
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/node/virtual_state_udr
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/ir_in
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/ir_out
add wave -noupdate -divider State
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/write_state
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/read_state
add wave -noupdate -divider Header
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/offset
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/header_in
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/scan_length
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/read_data_length
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/write_data_length
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/decoded_scan_length
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/decoded_write_data_length
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/decoded_read_data_length
add wave -noupdate -divider Misc
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/bytestream_end
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/scan_length_byte_counter
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/valid_write_data_length_byte_counter
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/bypass_bit_counter
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/header_in_bit_counter
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/header_out_bit_counter
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/dr_data_in
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/dr_data_out
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/dr_debug
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/dr_info
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/dr_control
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/padded_bit_counter
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/write_data_bit_counter
add wave -noupdate -radix hexadecimal /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/read_data_bit_counter
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/write_data_valid
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/read_data_valid
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/read_data_all_valid
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/decode_header_1
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/decode_header_2
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/write_data_byte_aligned
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/read_data_byte_aligned
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/padded_bit_byte_aligned
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/clock_sensor
add wave -noupdate /jtag_to_avalon_st_tb/u1/normal/jtag_dc_streaming/jtag_streaming/data_available
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 3} {410990000 ps} 0}
configure wave -namecolwidth 518
configure wave -valuecolwidth 74
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {408888182 ps} {412340960 ps}
