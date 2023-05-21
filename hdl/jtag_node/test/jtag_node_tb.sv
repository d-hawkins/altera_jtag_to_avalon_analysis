// ----------------------------------------------------------------
// jtag_node_tb.sv
//
// 9/14/11 D. W. Hawkins (dwh@caltech.edu)
//
// This testbench exercises the tasks within the component
// altera_jtag_sld_node.v. This component is the basis for
// the JTAG-to-Avalon-ST bridge, which in turn is used to create
// the JTAG-to-Avalon-MM bridge. These simulation procedures
// provide the basis for the JTAG-to-Avalon-ST/MM testbenches.
//
// The default TCK frequency is 20MHz (50ns period). The test
// uses a more realistic frequency of 6MHz (166ns)
//
// ----------------------------------------------------------------

`timescale 1 ns / 1 ns

module jtag_node_tb
	#(
		// JTAG clock frequency
		parameter real TCK_FREQ = 6.0e6
	);

	// ------------------------------------------------------------
	// Signals
	// ------------------------------------------------------------
	//
	logic [2:0] ir_out;
	logic tdo;
	logic [2:0] ir_in;
	logic tck;
	logic tdi;
	logic vs_cdr;
	logic vs_sdr;
	logic vs_e1dr;
	logic vs_udr;

	// These four signals are not driven by the simulation model
	// (they show up as tri-state in the Modelsim waveform view)
	logic vs_e2dr;
	logic vs_pdr;
	logic vs_cir;
	logic vs_uir;

	// ------------------------------------------------------------
	// Device under test
	// ------------------------------------------------------------
	//
	altera_jtag_sld_node
		#(
			.TCK_FREQ_MHZ(TCK_FREQ/1.0e6)
		)
		u1 (
    	.ir_out,
   		.tdo,
    	.ir_in,
    	.tck,
    	.tdi,
    	.virtual_state_cdr(vs_cdr),
    	.virtual_state_cir(vs_cir),
    	.virtual_state_e1dr(vs_e1dr),
    	.virtual_state_e2dr(vs_e2dr),
    	.virtual_state_pdr(vs_pdr),
    	.virtual_state_sdr(vs_sdr),
    	.virtual_state_udr(vs_udr),
    	.virtual_state_uir(vs_uir)
	);

	// Unused input
	assign ir_out = '0;

	// Loopback
	assign tdo = tdi;

	// ------------------------------------------------------------
	// Test sequences
	// ------------------------------------------------------------
	logic [7:0] rddata = '0;
	logic [7:0] wrdata = '0;
	int test_number = 0;
	initial
	begin
		// --------------------------------------------------------
		$display("----------------------------------------------");
		$display("Reset the JTAG controller");
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		test_number = test_number + 1;
		u1.reset_jtag_state;
		repeat (4) @(posedge tck);

		// --------------------------------------------------------
		$display("----------------------------------------------");
		$display("Cycle through each of the IR modes");
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		// The SLD node has five operating modes (IR values)
		//
		//   DATA     = 0 (default at reset)
		//   LOOPBACK = 1
		//   DEBUG    = 2
		//   INFO     = 3
		//   CONTROL  = 4
		//
		// Change ir_in to each of the modes
		test_number = test_number + 1;
		repeat (4) @(posedge tck);

		$display(" * IR mode = LOOPBACK");
		u1.enter_loopback_mode;

		$display(" * IR mode = DEBUG");
		u1.enter_debug_mode;

		$display(" * IR mode = INFO");
		u1.enter_info_mode;

		$display(" * IR mode = CONTROL");
		u1.enter_control_mode;

		// Then back to data
		$display(" * Set the IR mode to DATA");
		u1.enter_data_mode;
		repeat (4) @(posedge tck);

		// --------------------------------------------------------
		$display("----------------------------------------------");
		$display("Single-byte Virtual shift-DR sequence");
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		// JTAG TAP sequence;
		//    TLR->RTI->SDRS->CDR->SDR->E1DR->UDR
		//
		// But the node does not have all of these state
		// indicators, so just pulse the ones that do exist.
		//
		test_number = test_number + 1;
		repeat (4) @(posedge tck);

		// This does nothing, as there is no vs_sdrs output
		u1.enter_sdrs_state;

		// Pulse vs_cdr
		u1.enter_cdr_state;

		// Assert vs_sdr and shift data
		wrdata = 'hA5;
		u1.shift_one_byte(wrdata, rddata);

		// Check the bytes
		$display(" * write byte = %.2Xh, read byte =  %.2Xh", wrdata, rddata);
		assert (wrdata == rddata) else
			$error("Error: write/read data did not match!");
		$display(" * Write/read data matched ok");

		// Pulse vs_e1dr
		u1.enter_e1dr_state;

		// Pulse vs_udr
		u1.enter_udr_state;

		// All deasserted
		u1.clear_states;
		repeat (4) @(posedge tck);

		// --------------------------------------------------------
		$display("----------------------------------------------");
		$display("Multi-byte Virtual shift-DR sequence");
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		test_number = test_number + 1;

		$display(" * JTAG transactions are both a write and a read");
		$display(" * The testbench loops TDI->TDO so write/read data should match");

		repeat (4) @(posedge tck);
		for (int i = 0; i < 10; i++)
		begin
			wrdata = 'h11 * (i+1);
			u1.shift_one_byte(wrdata, rddata);

			$display(" * write byte = %.2Xh, read byte =  %.2Xh", wrdata, rddata);
			assert (wrdata == rddata) else
				$error("Error: write/read data did not match!");
		end
		$display(" * Write/read data matched ok");

		// All deasserted
		u1.clear_states;

		repeat (4) @(posedge tck);

		// --------------------------------------------------------
		$display("Simulation complete.");
		// --------------------------------------------------------
		$stop;
	end


endmodule



