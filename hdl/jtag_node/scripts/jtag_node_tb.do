onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /jtag_node_tb/test_number
add wave -noupdate /jtag_node_tb/tck
add wave -noupdate /jtag_node_tb/tdi
add wave -noupdate /jtag_node_tb/tdo
add wave -noupdate -radix hexadecimal /jtag_node_tb/ir_out
add wave -noupdate -radix hexadecimal /jtag_node_tb/ir_in
add wave -noupdate /jtag_node_tb/vs_cdr
add wave -noupdate /jtag_node_tb/vs_sdr
add wave -noupdate /jtag_node_tb/vs_e1dr
add wave -noupdate /jtag_node_tb/vs_udr
add wave -noupdate /jtag_node_tb/vs_e2dr
add wave -noupdate /jtag_node_tb/vs_pdr
add wave -noupdate /jtag_node_tb/vs_cir
add wave -noupdate /jtag_node_tb/vs_uir
add wave -noupdate -radix hexadecimal /jtag_node_tb/wrdata
add wave -noupdate -radix hexadecimal /jtag_node_tb/rddata
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1775000 ps} 0}
configure wave -namecolwidth 223
configure wave -valuecolwidth 100
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
WaveRestoreZoom {0 ps} {22223250 ps}
