// ----------------------------------------------------------------
// jtag_to_avalon_st_tb.sv
//
// 9/14/2011 D. W. Hawkins (dwh@caltech.edu)
//
// JTAG-to-Avalon-ST bridge testbench.
//
// This testbench generates JTAG sequences to determine the bridge
// protocol. The protocol can then be used to create Tcl procedures
// to access the component from quartus_stp (where Altera does not
// provide Tcl access procedures).
//
// ----------------------------------------------------------------

`timescale 1 ns / 1 ns

// JTAG Virtual TAP model
`define VTAP u1.normal.jtag_dc_streaming.jtag_streaming.node

module jtag_to_avalon_st_tb
	#(
		// Clock frequency
		parameter real CLK_FREQ     = 50.0e6
	);

	// ------------------------------------------------------------
	// Local parameters
	// ------------------------------------------------------------
	//
	// Clock period
	localparam time CLK_PERIOD = (1.0e9/CLK_FREQ)*1ns;

	// ------------------------------------------------------------
	// Signals
	// ------------------------------------------------------------
	//
   logic       clk;
   logic       reset_n;
   logic [7:0] source_data;
   logic       source_ready;
   logic       source_valid;
   logic [7:0] sink_data;
   logic       sink_valid;
   logic       sink_ready;
   logic       resetrequest;
   logic       enable_loopback;

	// ------------------------------------------------------------
	// Clock generator
	// ------------------------------------------------------------
	//
	initial
		clk = 1'b0;
	always
		#(CLK_PERIOD/2) clk <= ~clk;

	// ------------------------------------------------------------
	// Device under test
	// ------------------------------------------------------------
	//
	altera_avalon_st_jtag_interface u1 (
		.clk,
		.reset_n,
		.source_ready,
		.source_data,
		.source_valid,
		.sink_data,
		.sink_valid,
		.sink_ready,
		.resetrequest
	);

	// ------------------------------------------------------------
	// Avalon-ST source data
	// ------------------------------------------------------------
	//
	// Log data coming out of the device.
	//  * The log messages can be compared to the stimulus messages
	//    to see the latency between bytes being transmitted at the
	//    JTAG interface and showing up on the Avalon-ST interface.
	//
	always @(posedge clk)
	begin
		if (source_valid == 1)
			$display("Avalon-ST source data = %.2Xh", source_data);
	end

	// Always ready to consume data
	assign source_ready = '1;

	// ------------------------------------------------------------
	// Avalon-ST sink data
	// ------------------------------------------------------------

	always_comb
	begin
		if (enable_loopback == 0)
		begin
			sink_valid = '0;
			sink_data  = '0;
		end
		else
		begin
			// This only works if the sink is ready
			// (for one of the tests it is not)
			sink_valid = source_valid;
			sink_data  = source_data;
		end
	end

	// ------------------------------------------------------------
	// Test sequences
	// ------------------------------------------------------------
	int test_number = 0;
	logic [7:0] wrdata, rddata;
	logic [15:0] header;
	int length = 0;
	int count = 0;
	int escape_wrdata = 0;
	int escape_rddata = 0;
	initial
	begin
		$display("");
		$display("===============================================");
		$display("JTAG-to-Avalon-ST Testbench");
		$display("===============================================");
		$display("");
		$display("Simulation settings:");
		$display(" * Clock frequency is %.2f MHz", CLK_FREQ/1.0e6);
		$display(" * Clock period is %.2f ns", 1.0e9/CLK_FREQ);
		$display("");

		// --------------------------------------------------------
		// Defaults
		// --------------------------------------------------------
		//
		// Assert the Avalon-ST bus reset
		reset_n <= 0;

		// No Avalon-ST loopback
		enable_loopback = 0;

		// --------------------------------------------------------
		// Generate JTAG sequences
		// --------------------------------------------------------
		//
		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: Reset the JTAG controller", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		`VTAP.reset_jtag_state;

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: Deassert Avalon-ST reset", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------

		// Synchronous deassertion
		@(posedge clk)
		reset_n <= 1;

		// --------------------------------------------------------
		$display("==============================================");
		$display("Test the VIR operating modes");
		$display("==============================================");
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
		repeat (4) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: LOOPBACK mode: check the loopback of a single byte", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		@(posedge `VTAP.tck);
		`VTAP.enter_loopback_mode;
		`VTAP.enter_cdr_state;

		// Write and read a byte
		wrdata = 'h56;
		`VTAP.shift_one_byte(wrdata, rddata);

		// The loopback data is read back one TCK period later
		// so the rddata = (wrdata << 1)
		$display(" * Loopback data was %.2Xh", rddata);
		wrdata = (wrdata << 1) & 'hFF;
		assert (rddata == wrdata) else
			$error(" * ERROR: loopback did not match expected data %.2Xh", wrdata);

		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: LOOPBACK mode: check the loopback of multiple bytes", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		@(posedge `VTAP.tck);
		`VTAP.enter_loopback_mode;
		`VTAP.enter_cdr_state;

		// Write and read multiple bytes
		for (int i = 0; i < 8; i++)
		begin
			wrdata = 'h12 + 'h11*i;
			`VTAP.shift_one_byte(wrdata, rddata);
			$display(" * Loopback data was %.2Xh", rddata);
			wrdata = (wrdata << 1) & 'hFF;
			assert (rddata == wrdata) else
				$error(" * ERROR: loopback did not match expected data %.2Xh", wrdata);
		end
		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: DEBUG mode", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		// The 3-bit debug register is loaded during CDR, and then
		// shifted out during SDR.
		//
		@(posedge `VTAP.tck);
		`VTAP.enter_debug_mode;
		`VTAP.enter_cdr_state;
		wrdata = 0;
		`VTAP.shift_one_byte(wrdata, rddata);
		$display(" * DEBUG[2:0] = %.2Xh", rddata);
		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: INFO mode", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		// The 11-bit info register is loaded during CDR, and then
		// shifted out during SDR.
		//
		@(posedge `VTAP.tck);
		`VTAP.enter_info_mode;
		`VTAP.enter_cdr_state;
		wrdata = 0;
		`VTAP.shift_one_byte(wrdata, rddata);
		$display(" * INFO[7:0] = %.2Xh", rddata);
		wrdata = 0;
		`VTAP.shift_one_byte(wrdata, rddata);
		$display(" * INFO[10:8] = %.2Xh", rddata);
		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: CONTROL mode; set resetrequest", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		// The 9-bit info register is loaded with zero during CDR,
		// so you always read-back zero. However, it is updated
		// during UDR.
		//
		@(posedge `VTAP.tck);
		`VTAP.enter_control_mode;
		`VTAP.enter_cdr_state;
		wrdata = 0;
		`VTAP.shift_one_byte(wrdata, rddata);
		$display(" * CONTROL[7:0] = %.2Xh", rddata);
		wrdata = 0;
		`VTAP.shift_one_bit(1, rddata[0]);
		$display(" * CONTROL[8] = %1b", rddata);
		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: CONTROL mode; clear resetrequest", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		// The 9-bit info register is loaded with zero during CDR,
		// so you always read-back zero. However, it is updated
		// during UDR.
		//
		@(posedge `VTAP.tck);
		`VTAP.enter_control_mode;
		`VTAP.enter_cdr_state;
		wrdata = 0;
		`VTAP.shift_one_byte(wrdata, rddata);
		$display(" * CONTROL[7:0] = %.2Xh", rddata);
		wrdata = 0;
		`VTAP.shift_one_bit(0, rddata[0]);
		$display(" * CONTROL[8] = %1b", rddata);
		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: DATA mode: transfer 1kB of encoded data", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;
		`VTAP.enter_cdr_state;

		// The SystemConsole bytestream command transfers 1kB
		//
		// Header FC03h
		//
		// 111_111_00_0000_0011b: R/W length = scan length = 1k
		//
		header = 'hFC03;
		$display(" * Send the header; %.4Xh", header);
		`VTAP.shift_one_byte(header[7:0],  rddata);
		`VTAP.shift_one_byte(header[15:8], rddata);

		// To avoid sending the IDLE and ESCAPE codes, send
		// a 1kB block of data, with 0x11 at the start 0x22
		// at the end, and alternating 0x55 0xAA in the body
		// (this matches the Tcl hardware test)
		//
		$display(" * Send a 1K block of write data");
		length = 0;
		count = 0;

		// Send the start-of-packet
		wrdata = 'h11;
		`VTAP.shift_one_byte(wrdata, rddata);
		// The read data should be the idle code
		if (rddata != 'h4A)
			$display(" * Error during SOP read data was %.2Xh", rddata);

		// Alternating 0x55, 0xAA
		while (length++ < 1022)
		begin
			if (length & 1)
				wrdata = 'h55;
			else
				wrdata = 'hAA;
			`VTAP.shift_one_byte(wrdata, rddata);
			assert (rddata == 'h4A) else
				$error(" * Error read data was %.2Xh", rddata);
		end

		// Send the end-of-packet
		wrdata = 'h22;
		`VTAP.shift_one_byte(wrdata, rddata);
		// The read data should be the idle code
		assert (rddata == 'h4A) else
			$error(" * Error during EOP read data was %.2Xh", rddata);

		$display(" * Transmitted/received 1kB ok");

		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: DATA mode: transfer 1kB of encoded data with loopback", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		enable_loopback = 1;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;
		`VTAP.enter_cdr_state;

		// Header FC03h
		//
		// 111_111_00_0000_0011b: R/W length = scan length = 1k
		//
		header = 'hFC03;
		$display(" * Send the header; %.4Xh", header);
		`VTAP.shift_one_byte(header[7:0],  rddata);
		`VTAP.shift_one_byte(header[15:8], rddata);

		// A 1k block of incrementing data
		$display(" * Send a 1K block of write data and report the read data");
		length = 0;
		count = 0;
		//
		// Since each write is also a read, the escaping of write and
		// read characters needs to be handled independently.
		//
		// An escape flag is used for each data path. Visual inspection
		// of the log messages shows that this logic correctly sees
		// read data as 49h, 4Ah, 4Bh, 4Ch, 4Dh, 4Eh, 4Fh, 50h, etc.,
		// with read escape codes received before 4Ah and 4Dh.
		//
		escape_wrdata = 0;
		escape_rddata = 0;
		while (length++ < 1024)
		begin
			if (escape_wrdata == 0)
				wrdata = count++ & 'hFF;
			else
			begin
				wrdata ^= 'h20;
				escape_wrdata = 0;
			end

			// Idle or Escape code?
			if ((wrdata == 'h4A) | (wrdata == 'h4D))
			begin
				escape_wrdata = 1;
			end

			// Send the write-data or escape code
			if (escape_wrdata == 0)
			begin
				// Change the last few writes to idles
				// so that all the loopbacks complete
				if (count > 1011)
					wrdata = 'h4A;

				`VTAP.shift_one_byte(wrdata, rddata);
			end
			else
				`VTAP.shift_one_byte('h4D, rddata);

			// The read data will be idle codes to start with, and then data
			if (rddata == 'h4A)
				continue;

			if (rddata == 'h4D)
			begin
				$display(" * Escape code received");
				escape_rddata = 1;
				continue;
			end

			if (escape_rddata == 1)
			begin
				// Modify the data
				rddata ^= 'h20;
				escape_rddata = 0;
			end

			$display(" * Index %0d read data was %.2Xh", count, rddata);
		end
		$display(" * Final count value was %.4Xh", count-1);

		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: DATA mode: again Avalon-ST looped back, but a different header", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		enable_loopback = 1;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;
		`VTAP.enter_cdr_state;

		// Header tests
		//
		// FC00h = 111_111_00_0000_0000b: R/W length = scan length = 256
		//   * this looks right, data is looped back,
		//     bytestream_end asserts at the end, and the
		//     valid_write_data_length_byte_counter ends
		//     at zero just as SDR deasserts
		//
		// FC01h = 111_111_00_0000_0001b: R/W length = scan length = 512
		//   * this looks wrong, as after 256 transfers the counters
		//     still have 256 left to go.
		//   * Ah, its wrong because my data loop only sends 256.
		//     I need to make sure the loop length is consistent
		//     with the header.
		//
		// 2400h = 001_001_00_0000_0000b: R/W length = 256, scan length = 256
		//   * this looks right, data is looped back,
		//     bytestream_end asserts at the end, and the
		//     valid_write_data_length_byte_counter ends
		//     at zero just as SDR deasserts
		//
		// 0400h = 000_001_00_0000_0000b: W length 0, R length = 256, scan length = 256
		//   * this looks right, bytestream_end asserts at the end
		//   * the valid_write_data_length_byte_counter stays at zero
		//     and no write data appears on the Avalon-ST bus
		//
		// 2000h = 001_000_00_0000_0000b: W length 256, R length = 0, scan length = 256
		//   * this looks right, bytestream_end asserts at the end
		//   * sink_ready deasserts, so that none of the loopback data is accepted,
		//     and no messages are printed regarding the read data
		//
		// So these last two modes provide a uni-directional stream.
		//
//		header = 'hFC00;
//		header = 'h2400;
//		header = 'h0400; // A read-only transfer
		header = 'h2000; // A write-only transfer (readback IDLE codes)
		$display(" * Send the header; %.4Xh", header);
		`VTAP.shift_one_byte(header[7:0],  rddata);
		`VTAP.shift_one_byte(header[15:8], rddata);

		// A 256 block of incrementing data
		$display(" * Send a 256-byte block of write data to the JTAG interface and report the read data");
		length = 0;
		count = 0;
		//
		// Since each write is also a read, the escaping of write and
		// read characters needs to be handled independently (sending
		// an escape character like the previous test does not work,
		// as the read data is not checked).
		//
		// An escape flag is used for each data path. Visual inspection
		// of the log messages shows that this logic correctly sees
		// read data as 49h, 4Ah, 4Bh, 4Ch, 4Dh, 4Eh, 4Fh, 50h, etc.,
		// with read escape codes received before 4Ah and 4Dh.
		//
		escape_wrdata = 0;
		escape_rddata = 0;
		while (length++ < 256)
		begin
			if (escape_wrdata == 0)
				wrdata = count++ & 'hFF;
			else
			begin
				wrdata ^= 'h20;
				escape_wrdata = 0;
			end

			// Idle or Escape code?
			if ((wrdata == 'h4A) | (wrdata == 'h4D))
			begin
				escape_wrdata = 1;
			end

			// Send the write-data or escape code
			if (escape_wrdata == 0)
			begin
				// Change the last few writes to idles
				// so that all the loopbacks complete
				if (count > 251)
					wrdata = 'h4A;

				`VTAP.shift_one_byte(wrdata, rddata);
			end
			else
				`VTAP.shift_one_byte('h4D, rddata);

			// The read data will be idle codes to start with, and then data
			if (rddata == 'h4A)
				continue;

			if (rddata == 'h4D)
			begin
				$display(" * Escape code received");
				escape_rddata = 1;
				continue;
			end

			if (escape_rddata == 1)
			begin
				// Modify the data
				rddata ^= 'h20;
				escape_rddata = 0;
			end

			$display(" * Index %0d read data was %.2Xh", count, rddata);
		end
		$display(" * Final count value was %.4Xh", count-1);

		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: DATA mode: do short writes screw things up?", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		enable_loopback = 1;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;
		`VTAP.enter_cdr_state;

		// Header tests
		//
		// FC00h = 111_111_00_0000_0000b: R/W length = scan length = 256
		header = 'hFC00;
		$display(" * Send the header; %.4Xh", header);
		`VTAP.shift_one_byte(header[7:0],  rddata);
		`VTAP.shift_one_byte(header[15:8], rddata);

		$display(" * Send a 16-byte block of write data and report the read data");
		length = 0;
		count = 0;
		escape_wrdata = 0;
		escape_rddata = 0;
		while (length++ < 16)
		begin
			if (escape_wrdata == 0)
				wrdata = count++ & 'hFF;
			else
			begin
				wrdata ^= 'h20;
				escape_wrdata = 0;
			end

			// Idle or Escape code?
			if ((wrdata == 'h4A) | (wrdata == 'h4D))
			begin
				escape_wrdata = 1;
			end

			// Send the write-data or escape code
			if (escape_wrdata == 0)
				`VTAP.shift_one_byte(wrdata, rddata);
			else
				`VTAP.shift_one_byte('h4D, rddata);

			// The read data will be idle codes to start with, and then data
			if (rddata == 'h4A)
				continue;

			if (rddata == 'h4D)
			begin
				$display(" * Escape code received");
				escape_rddata = 1;
				continue;
			end

			if (escape_rddata == 1)
			begin
				// Modify the data
				rddata ^= 'h20;
				escape_rddata = 0;
			end

			$display(" * Index %0d read data was %.2Xh", count, rddata);
		end
		$display(" * Final count value was %.4Xh", count-1);

		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: DATA mode: another short write ...", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		enable_loopback = 1;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;
		`VTAP.enter_cdr_state;

		// Header tests
		//
		// FC00h = 111_111_00_0000_0000b: R/W length = scan length = 256
		header = 'hFC00;
		$display(" * Send the header; %.4Xh", header);
		`VTAP.shift_one_byte(header[7:0],  rddata);
		$display(" * Header response [7:0]; %.2Xh", rddata);
		if (rddata[0] == 1)
			$display(" * There is read data available");
		`VTAP.shift_one_byte(header[15:8], rddata);
		$display(" * Header response [15:8]; %.2Xh", rddata);

		$display(" * Send a 16-byte block of write data and report the read data");
		length = 0;
		count = 0;
		escape_wrdata = 0;
		escape_rddata = 0;
		while (length++ < 16)
		begin
			if (escape_wrdata == 0)
				wrdata = count++ & 'hFF;
			else
			begin
				wrdata ^= 'h20;
				escape_wrdata = 0;
			end

			// Idle or Escape code?
			if ((wrdata == 'h4A) | (wrdata == 'h4D))
			begin
				escape_wrdata = 1;
			end

			// Send the write-data or escape code
			if (escape_wrdata == 0)
				`VTAP.shift_one_byte(wrdata, rddata);
			else
				`VTAP.shift_one_byte('h4D, rddata);

			// The read data will be idle codes to start with, and then data
			if (rddata == 'h4A)
				continue;

			if (rddata == 'h4D)
			begin
				$display(" * Escape code received");
				escape_rddata = 1;
				continue;
			end

			if (escape_rddata == 1)
			begin
				// Modify the data
				rddata ^= 'h20;
				escape_rddata = 0;
			end

			$display(" * Index %0d read data was %.2Xh", count, rddata);
		end
		$display(" * Final count value was %.4Xh", count-1);

		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: DATA mode: and another short write ...", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		enable_loopback = 1;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;
		`VTAP.enter_cdr_state;

		// Header tests
		//
		// FC00h = 111_111_00_0000_0000b: R/W length = scan length = 256
		header = 'hFC00;
		$display(" * Send the header; %.4Xh", header);
		`VTAP.shift_one_byte(header[7:0],  rddata);
		$display(" * Header response [7:0]; %.2Xh", rddata);
		if (rddata[0] == 1)
			$display(" * There is read data available");
		`VTAP.shift_one_byte(header[15:8], rddata);
		$display(" * Header response [15:8]; %.2Xh", rddata);

		$display(" * Send a 16-byte block of write data and report the read data");
		length = 0;
		count = 0;
		escape_wrdata = 0;
		escape_rddata = 0;
		while (length++ < 16)
		begin
			if (escape_wrdata == 0)
				wrdata = count++ & 'hFF;
			else
			begin
				wrdata ^= 'h20;
				escape_wrdata = 0;
			end

			// Idle or Escape code?
			if ((wrdata == 'h4A) | (wrdata == 'h4D))
			begin
				escape_wrdata = 1;
			end

			// Send the write-data or escape code
			if (escape_wrdata == 0)
				`VTAP.shift_one_byte(wrdata, rddata);
			else
				`VTAP.shift_one_byte('h4D, rddata);

			// The read data will be idle codes to start with, and then data
			if (rddata == 'h4A)
				continue;

			if (rddata == 'h4D)
			begin
				$display(" * Escape code received");
				escape_rddata = 1;
				continue;
			end

			if (escape_rddata == 1)
			begin
				// Modify the data
				rddata ^= 'h20;
				escape_rddata = 0;
			end

			$display(" * Index %0d read data was %.2Xh", count, rddata);
		end
		$display(" * Final count value was %.4Xh", count-1);

		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;

		repeat (10) @(posedge clk);

		// -------------------------------------------------------
		// NOTE:
		//
		// It appears the short reads lose the last valid
		// write data looped back over the Avalon-ST interface.
		//
		// Lets see if a valid back-to-back sequence manages
		// to get all data.
		//
		// -------------------------------------------------------

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: DATA mode: short-read read-only (to flush the stream)", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		enable_loopback = 1;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;
		`VTAP.enter_cdr_state;

		header = 'h0400; // read-only
		$display(" * Send the header; %.4Xh", header);
		`VTAP.shift_one_byte(header[7:0],  rddata);
		$display(" * Header response [7:0]; %.2Xh", rddata);
		if (rddata[0] == 1)
			$display(" * There is read data available");
		`VTAP.shift_one_byte(header[15:8], rddata);
		$display(" * Header response [15:8]; %.2Xh", rddata);

		$display(" * Send a 16-byte block of write data and report the read data");
		length = 0;
		count = 0;
		escape_wrdata = 0;
		escape_rddata = 0;
		while (length++ < 16)
		begin
			if (escape_wrdata == 0)
				wrdata = count++ & 'hFF;
			else
			begin
				wrdata ^= 'h20;
				escape_wrdata = 0;
			end

			// Idle or Escape code?
			if ((wrdata == 'h4A) | (wrdata == 'h4D))
			begin
				escape_wrdata = 1;
			end

			// Send the write-data or escape code
			if (escape_wrdata == 0)
				`VTAP.shift_one_byte(wrdata, rddata);
			else
				`VTAP.shift_one_byte('h4D, rddata);

			// The read data will be idle codes to start with, and then data
			if (rddata == 'h4A)
				continue;

			if (rddata == 'h4D)
			begin
				$display(" * Escape code received");
				escape_rddata = 1;
				continue;
			end

			if (escape_rddata == 1)
			begin
				// Modify the data
				rddata ^= 'h20;
				escape_rddata = 0;
			end

			$display(" * Index %0d read data was %.2Xh", count, rddata);
		end
		$display(" * Final count value was %.4Xh", count-1);

		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: DATA mode: full-length write", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		enable_loopback = 1;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;
		`VTAP.enter_cdr_state;

		header = 'hFC00;
		$display(" * Send the header; %.4Xh", header);
		`VTAP.shift_one_byte(header[7:0],  rddata);
		$display(" * Header response [7:0]; %.2Xh", rddata);
		if (rddata[0] == 1)
			$display(" * There is read data available");
		`VTAP.shift_one_byte(header[15:8], rddata);
		$display(" * Header response [15:8]; %.2Xh", rddata);

		$display(" * Send a 16-byte block of write data and report the read data");
		length = 0;
		count = 0;
		escape_wrdata = 0;
		escape_rddata = 0;
		while (length++ < 256)
		begin
			if (escape_wrdata == 0)
				wrdata = count++ & 'hFF;
			else
			begin
				wrdata ^= 'h20;
				escape_wrdata = 0;
			end

			// Idle or Escape code?
			if ((wrdata == 'h4A) | (wrdata == 'h4D))
			begin
				escape_wrdata = 1;
			end

			// Send the write-data or escape code
			if (escape_wrdata == 0)
				`VTAP.shift_one_byte(wrdata, rddata);
			else
				`VTAP.shift_one_byte('h4D, rddata);

			// The read data will be idle codes to start with, and then data
			if (rddata == 'h4A)
				continue;

			if (rddata == 'h4D)
			begin
				$display(" * Escape code received");
				escape_rddata = 1;
				continue;
			end

			if (escape_rddata == 1)
			begin
				// Modify the data
				rddata ^= 'h20;
				escape_rddata = 0;
			end

			$display(" * Index %0d read data was %.2Xh", count, rddata);
		end
		$display(" * Final count value was %.4Xh", count-1);

		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display("#%0d: DATA mode: short-read read-only (to flush the stream)", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		enable_loopback = 1;
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;
		`VTAP.enter_cdr_state;

		header = 'h0400; // read-only
		$display(" * Send the header; %.4Xh", header);
		`VTAP.shift_one_byte(header[7:0],  rddata);
		$display(" * Header response [7:0]; %.2Xh", rddata);
		if (rddata[0] == 1)
			$display(" * There is read data available");
		`VTAP.shift_one_byte(header[15:8], rddata);
		$display(" * Header response [15:8]; %.2Xh", rddata);

		$display(" * Send a 16-byte block of write data and report the read data");
		length = 0;
		count = 0;
		escape_wrdata = 0;
		escape_rddata = 0;
		while (length++ < 16)
		begin
			if (escape_wrdata == 0)
				wrdata = count++ & 'hFF;
			else
			begin
				wrdata ^= 'h20;
				escape_wrdata = 0;
			end

			// Idle or Escape code?
			if ((wrdata == 'h4A) | (wrdata == 'h4D))
			begin
				escape_wrdata = 1;
			end

			// Send the write-data or escape code
			if (escape_wrdata == 0)
				`VTAP.shift_one_byte(wrdata, rddata);
			else
				`VTAP.shift_one_byte('h4D, rddata);

			// The read data will be idle codes to start with, and then data
			if (rddata == 'h4A)
				continue;

			if (rddata == 'h4D)
			begin
				$display(" * Escape code received");
				escape_rddata = 1;
				continue;
			end

			if (escape_rddata == 1)
			begin
				// Modify the data
				rddata ^= 'h20;
				escape_rddata = 0;
			end

			$display(" * Index %0d read data was %.2Xh", count, rddata);
		end
		$display(" * Final count value was %.4Xh", count-1);

		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
		`VTAP.clear_states;

		// -------------------------------------------------------
		// NOTE:
		//
		// So this short-read printed out the looped back data
		// that was consecutive to the data printed during the
		// previous loopback test.
		//
		// Short writes/reads can cause the loss of read-data
		//
		// -------------------------------------------------------

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		$display("----------------------------------------------");
		$display("Simulation complete.");
		$display("----------------------------------------------");
		// --------------------------------------------------------
		$stop;
	end


endmodule



