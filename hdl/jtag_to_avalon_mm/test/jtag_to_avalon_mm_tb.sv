// ----------------------------------------------------------------
// jtag_to_avalon_mm_tb.sv
//
// 10/1/2011 D. W. Hawkins (dwh@caltech.edu)
//
// JTAG-to-Avalon-MM bridge testbench.
//
// This testbench generates JTAG sequences that were determined
// from SignalTap II traces from hardware. The Verilog tasks
// for Avalon-MM reads and writes perform like the SystemConsole
// commands of the same names.
//
// The bridge protocol implemented in this testbench can be used
// to create Tcl procedures to access the component from
// quartus_stp (where Altera does not provide Tcl access
// procedures).
//
// ----------------------------------------------------------------
// Notes
// -----
//
// 1. The Avalon-MM multiple word read/write routines probably
//    do not work under all circumstances. The main purpose of
//    this testbench was to confirm the operation of the protocols.
//    The quartus_stp Tcl routines perform much more careful
//    checks.
//
// ----------------------------------------------------------------

`timescale 1 ns / 1 ns

// JTAG Virtual TAP model
//
//                                                                                                                 altera_avalon_st_jtag_interface
`define VTAP u1.normal.altera_jtag_avalon_master_pli_off_inst.the_altera_jtag_avalon_master_jtag_interface_pli_off.altera_jtag_avalon_master_jtag_interface_pli_off.normal.jtag_dc_streaming.jtag_streaming.node

module jtag_to_avalon_mm_tb
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
	logic        clk;
	logic        reset_n;
	logic        mm_read;
	logic        mm_write;
	logic [31:0] mm_addr;
	logic [ 3:0] mm_byteen;
	logic [31:0] mm_wrdata;
	logic [31:0] mm_rddata;
	logic        mm_wait;
	logic        mm_rdvalid;
	logic        mm_resetrequest;
	logic [31:0] mm_registers[32];  // block of 32 registers

	// ------------------------------------------------------------
	// Clock generator
	// ------------------------------------------------------------
	//
	initial
		clk = 1'b0;
	always
		#(CLK_PERIOD/2) clk <= ~clk;

	initial
	begin
		reset_n <= 0;
		#100 reset_n <= 1;
	end

	// ------------------------------------------------------------
	// Device under test
	// ------------------------------------------------------------
	//
	altera_jtag_avalon_master u1 (
		.clk(clk),
		.reset_n(reset_n),

		// Avalon-MM master
		.read_from_the_altera_jtag_avalon_master_packets_to_transactions_converter       (mm_read),
		.write_from_the_altera_jtag_avalon_master_packets_to_transactions_converter      (mm_write),
		.byteenable_from_the_altera_jtag_avalon_master_packets_to_transactions_converter (mm_byteen),
		.address_from_the_altera_jtag_avalon_master_packets_to_transactions_converter    (mm_addr),
		.readdata_to_the_altera_jtag_avalon_master_packets_to_transactions_converter     (mm_rddata),
		.writedata_from_the_altera_jtag_avalon_master_packets_to_transactions_converter  (mm_wrdata),
		.readdatavalid_to_the_altera_jtag_avalon_master_packets_to_transactions_converter(mm_rdvalid),
		.waitrequest_to_the_altera_jtag_avalon_master_packets_to_transactions_converter  (mm_wait),

		// Reset request
		.resetrequest_from_the_altera_jtag_avalon_master_jtag_interface(mm_resetrequest)

	);

	// ------------------------------------------------------------
	// An Avalon-MM register
	// ------------------------------------------------------------
	//
	always @(posedge clk or negedge reset_n)
	begin
		if (~reset_n)
		begin
			mm_wait      <= 1;
			mm_rdvalid   <= 0;
			for (int i = 0; i < 32; i++)
				mm_registers[i] <= 0;
		end
		else
		begin
			// Always ready
			mm_wait <= 0;

			// Single pipeline delay
			mm_rdvalid <= mm_read;

			// Write (no address decode)
			if (mm_write == 1)
				mm_registers[mm_addr[6:2]] <= mm_wrdata;
		end
	end

	// The registers are 32-bit aligned
	// (so ignore the 2-LSBs of the master address)
	assign mm_rddata = mm_registers[mm_addr[6:2]];

	// ------------------------------------------------------------
	// Test sequences
	// ------------------------------------------------------------
	int test_number = 0;
	logic [31:0] avalon_addr, avalon_wrdata, avalon_rddata;
	logic [31:0] avalon_wrdatam[];
	logic [31:0] avalon_rddatam[];
	logic [7:0] wrdata, rddata;
	logic [7:0] bytestream[256];
	logic [15:0] header;
	int length = 0;
	int count = 0;
	int escape_wrdata = 0;
	int escape_rddata = 0;
	initial
	begin
		$display("");
		$display("===============================================");
		$display("JTAG-to-Avalon-MM Testbench");
		$display("===============================================");
		$display("");
		$display("Simulation settings:");
		$display(" * Clock frequency is %.2f MHz", CLK_FREQ/1.0e6);
		$display(" * Clock period is %.2f ns", 1.0e9/CLK_FREQ);
		$display("");

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: Reset the JTAG controller", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		`VTAP.reset_jtag_state;

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: Wait for the Avalon-MM reset to deassert", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		// Wait for reset to deassert
		@(posedge reset_n)

		// --------------------------------------------------------
		$display("==============================================");
		$display("Test the VIR operations modes");
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
		$display(" * CONTROL[8:0] = %.3Xh", rddata);
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
		$display(" #%0d: DATA mode: issue an Avalon-MM write 32-bit command", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		avalon_addr   = 32'h11223344;
		avalon_wrdata = 32'h55667788;
		$display(" * write (addr, data) = (%.8Xh, %.8Xh)", avalon_addr, avalon_wrdata);
		master_write_32(avalon_addr, avalon_wrdata);

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: DATA mode: issue an Avalon-MM read 32-bit command", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		avalon_addr   = 32'h11223344;
		avalon_wrdata = 32'h55667788;
		master_read_32(avalon_addr, avalon_rddata);
		$display(" * read (addr, data) = (%.8Xh, %.8Xh)", avalon_addr, avalon_rddata);
		assert (avalon_rddata == avalon_wrdata) else
			$error(" * ERROR: the Avalon-MM read data %.8X did not match the expected data %.8Xh", avalon_rddata, avalon_wrdata);

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: DATA mode: issue an Avalon-MM write 32-bit multiple command", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		avalon_addr   = 32'h11223344;
		avalon_wrdatam = new[32];
		foreach (avalon_wrdatam[i])
			avalon_wrdatam[i] = 32'h03020100 + 32'h04040404*i;
		foreach (avalon_wrdatam[i])
			$display(" * write (addr, data) = (%.8Xh, %.8Xh)", avalon_addr+4*i, avalon_wrdatam[i]);
		master_write_32m(avalon_addr, avalon_wrdatam);

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		test_number = test_number + 1;
		$display("----------------------------------------------");
		$display(" #%0d: DATA mode: issue an Avalon-MM read 32-bit multiple command", test_number);
		$display("----------------------------------------------");
		// --------------------------------------------------------
		//
		avalon_addr   = 32'h11223344;
		master_read_32m(avalon_addr, avalon_rddatam, 32);
		foreach (avalon_rddatam[i])
			$display(" * read (addr, data) = (%.8Xh, %.8Xh)", avalon_addr+4*i, avalon_rddatam[i]);
		foreach (avalon_rddatam[i])
			assert (avalon_rddatam[i] == avalon_wrdatam[i]) else
			$error(" * ERROR: the Avalon-MM read data %.8X did not match the expected data %.8Xh", avalon_rddatam[i], avalon_wrdatam[i]);
		$display(" * Read data matches the write data");

		// Delete the read and write data vectors
		avalon_wrdatam.delete();
		avalon_rddatam.delete();

		repeat (10) @(posedge clk);

		// --------------------------------------------------------
		$display("----------------------------------------------");
		$display("Simulation complete.");
		$display("----------------------------------------------");
		// --------------------------------------------------------
		$stop;
	end

	// ============================================================
	// Tasks
	// ============================================================
	//
	// Avalon-MM read and write procedures.
	//
	// ------------------------------------------------------------
	task master_write_32 (
	// ------------------------------------------------------------
		input [31:0] addr,
		input [31:0] data
	);
		// Local variables
		logic [7:0] txbytes[12];
		logic [7:0] pkbytes[256]; // Between 16- and 24-bytes
		logic [7:0] wrbytes[256];
		logic [7:0] rdbytes[256];
		int pkindex;
		int wrindex;
		int rdindex;
		int byteindex;

	begin
		// Put the JTAG-to-Avalon-ST bridge in data mode
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;

		// Virtual JTAG capture-DR state
		`VTAP.enter_cdr_state;

		// Avalon-MM transaction bytes format
		//
		//  Byte   Value  Description
		// ------  -----  -----------
		//    [0]  0x00   Transaction code = write, with increment
		//    [1]  0x00   Reserved
		//  [3:2]  0x0004 16-bit size (big-endian byte order)
		//  [7:4]  32-bit address (big-endian byte order)
		// [11:8]  32-bit data (little-endian byte order)
		//
		// The transaction code could be write without increment,
		// however, write with increment is used, as this matches
		// the SignalTap II traces.
		//
		txbytes[0]  = 4;           // Write, with increment
		txbytes[1]  = 0;           // Reserved
		txbytes[2]  = 0;           // 16-bit size (big-endian)
		txbytes[3]  = 4;
		txbytes[4]  = addr[31:24]; // Address (big-endian)
		txbytes[5]  = addr[23:16];
		txbytes[6]  = addr[15: 8];
		txbytes[7]  = addr[ 7: 0];
		txbytes[8]  = data[ 7: 0]; // Data (little-endian)
		txbytes[9]  = data[15: 8];
		txbytes[10] = data[23:16];
		txbytes[11] = data[31:24];

		// Encode the transaction to packet bytes format
		//
		// Byte    Value  Description
		// -----   -----  ----------
		//  [0]    0x00   Channel number
		//  [1]    0x7A   Start-of-packet
		//  [X:2]         Transaction bytes with escape codes
		//         0x7B   End-of-packet
		//  [Y]           Last transaction byte (or escape code plus byte)
		//
		pkbytes[0]  = 'h7C;  // Channel
		pkbytes[1]  = 'h00;
		pkbytes[2]  = 'h7A;  // SOP

		// Insert the transaction bytes, escaping as needed
		pkindex = 3;
		for (int i = 0; i < 12; i++)
		begin
			// Insert the end-of-packet (before the last data/escaped data)
			if (i == 11)
			begin
				pkbytes[pkindex++] = 'h7B;
			end

			// Escape code required?
			if ((txbytes[i] >= 'h7A) && (txbytes[i] <= 'h7D))
			begin
				// Insert the escape code and modified byte
				pkbytes[pkindex++] = 'h7D;
				pkbytes[pkindex++] = txbytes[i] ^ 'h20;
			end
			else
			begin
				pkbytes[pkindex++] = txbytes[i];
			end
		end

		// Encode the packet bytes in JTAG-to-Avalon-ST format
		//
		// Byte    Value  Description
		// -----   -----  ----------
		//  [1:0]  0xFC00 JTAG-to-Avalon-ST packet header (256-bytes)
		// [X-1:2]        Transaction bytes with escape codes
		// [255:X]        JTAG-to-Avalon-ST IDLE codes
		//
		// FC00 = 111_111_00_0000_0000b
		//   write length = read length = scan length = 256-bytes
		//
		wrbytes[0]  = 'h00;  // FC00h header
		wrbytes[1]  = 'hFC;

		// Insert the transaction bytes, escaping as needed
		wrindex = 2;
		for (int i = 0; i < pkindex; i++)
		begin
			// Escape code required?
			if ((pkbytes[i] == 'h4A) || (pkbytes[i] == 'h4D))
			begin
				// Insert the escape code and modified byte
				wrbytes[wrindex++] = 'h4D;
				wrbytes[wrindex++] = pkbytes[i] ^ 'h20;
			end
			else
			begin
				wrbytes[wrindex++] = pkbytes[i];
			end
		end

		// Fill the remainder of the transaction with JTAG IDLE codes
		for (int i = wrindex; i < 256; i++)
			wrbytes[i] = 'h4A;

		// Send the bytes and capture the response bytes
		for (int i = 0; i < 256; i++)
		begin
			`VTAP.shift_one_byte(wrbytes[i],  rdbytes[i]);
		end

		// Parse and check the response data
		//
		// Bytes  Value  Description
		// -----  -----  -----------
		//  [0]    0x7C  Channel
		//  [1]    0x00  Channel number
		//  [2]    0x7A  Start-of-packet
		//  [3]    0x80  Transaction code with MSB set
		//  [4]    0x00  Reserved
		//  [5]    0x00  Size[15:8]
		//  [6]    0x7B  End-of-packet
		//  [7]    0x04  Size[7:0]
		//
		// Since the response data for a write does not contain
		// encoded characters, they are not checked (see the
		// master_read_32 task for how its done).
		//
		// Find the channel code
		// (the beginning of the response packet)
		rdindex = 0;
		while ((rdindex < 256) && (rdbytes[rdindex++] != 'h7C));
		assert (rdindex < 256) else $error("Channel code not detected!");

		// Check all the response bytes
		assert (rdbytes[rdindex++] == 0)    else $error("Channel number error!");
		assert (rdbytes[rdindex++] == 'h7A) else $error("Start-of-packet code error!");
		assert (rdbytes[rdindex++] == 'h84) else $error("Transaction code error!");
		assert (rdbytes[rdindex++] == 'h00) else $error("Reserved code error!");
		assert (rdbytes[rdindex++] == 'h00) else $error("Size MSBs error!");
		assert (rdbytes[rdindex++] == 'h7B) else $error("End-of-packet code error!");
		assert (rdbytes[rdindex++] == 'h04) else $error("Size LSBs error!");

		// Virtual JTAG Exit1-DR and then Update-DR state
		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;
	end
	endtask

	// ------------------------------------------------------------
	task master_read_32 (
	// ------------------------------------------------------------
		input  [31:0] addr,
		output [31:0] data
	);
		// Local variables
		logic [7:0] txbytes[8];
		logic [7:0] pkbytes[256];
		logic [7:0] wrbytes[256];
		logic [7:0] rdbytes[256];
		int pkindex;
		int wrindex;
		int rdindex;
		int byteindex;

	begin

		// Put the JTAG-to-Avalon-ST bridge in data mode
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;

		// Virtual JTAG capture-DR state
		`VTAP.enter_cdr_state;

		// Avalon-MM transaction bytes format
		//
		//  Byte   Value  Description
		// ------  -----  -----------
		//    [0]  0x14   Transaction code = read, with increment
		//    [1]  0x00   Reserved
		//  [3:2]  0x0004 16-bit size (big-endian byte order)
		//  [7:4]  32-bit address (big-endian byte order)
		//
		// The transaction code could be read without increment,
		// however, read with increment is used, as this matches
		// the SignalTap II traces.
		//
		txbytes[0]  = 'h14;        // Read, with increment
		txbytes[1]  = 0;           // Reserved
		txbytes[2]  = 0;           // 16-bit size (big-endian)
		txbytes[3]  = 4;
		txbytes[4]  = addr[31:24]; // Address (big-endian)
		txbytes[5]  = addr[23:16];
		txbytes[6]  = addr[15: 8];
		txbytes[7]  = addr[ 7: 0];

		// Encode the transaction to packet bytes format
		//
		// Byte    Value  Description
		// -----   -----  ----------
		//  [0]    0x00   Channel number
		//  [1]    0x7A   Start-of-packet
		//  [X:2]         Transaction bytes with escape codes
		//         0x7B   End-of-packet
		//  [Y]           Last transaction byte (or escape code plus byte)
		//
		pkbytes[0]  = 'h7C;  // Channel
		pkbytes[1]  = 'h00;
		pkbytes[2]  = 'h7A;  // SOP

		// Insert the transaction bytes, escaping as needed
		pkindex = 3;
		for (int i = 0; i < 8; i++)
		begin
			// Insert the end-of-packet (before the last data/escaped data)
			if (i == 7)
			begin
				pkbytes[pkindex++] = 'h7B;
			end

			// Escape code required?
			if ((txbytes[i] >= 'h7A) && (txbytes[i] <= 'h7D))
			begin
				// Insert the escape code and modified byte
				pkbytes[pkindex++] = 'h7D;
				pkbytes[pkindex++] = txbytes[i] ^ 'h20;
			end
			else
			begin
				pkbytes[pkindex++] = txbytes[i];
			end
		end

		// Encode the packet bytes in JTAG-to-Avalon-ST format
		//
		// Byte    Value  Description
		// -----   -----  ----------
		//  [1:0]  0xFC00 JTAG-to-Avalon-ST packet header (256-bytes)
		// [X-1:2]        Transaction bytes with escape codes
		// [255:X]        JTAG-to-Avalon-ST IDLE codes
		//
		// FC00 = 111_111_00_0000_0000b
		//   write length = read length = scan length = 256-bytes
		//
		wrbytes[0]  = 'h00;  // FC00h header
		wrbytes[1]  = 'hFC;

		// Insert the transaction bytes, escaping as needed
		wrindex = 2;
		for (int i = 0; i < pkindex; i++)
		begin
			// Escape code required?
			if ((pkbytes[i] == 'h4A) || (pkbytes[i] == 'h4D))
			begin
				// Insert the escape code and modified byte
				wrbytes[wrindex++] = 'h4D;
				wrbytes[wrindex++] = pkbytes[i] ^ 'h20;
			end
			else
			begin
				wrbytes[wrindex++] = pkbytes[i];
			end
		end

		// Fill the remainder of the transaction with JTAG IDLE codes
		for (int i = wrindex; i < 256; i++)
			wrbytes[i] = 'h4A;

		// Send the byte stream
		for (int i = 0; i < 256; i++)
		begin
			`VTAP.shift_one_byte(wrbytes[i],  rdbytes[i]);
		end

		// Virtual JTAG Exit1-DR and then Update-DR state
		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;

		// Parse and extract the read data
		//
		// The read byte stream consists of;
		// * the 16-bit read data header (the LSB indicates
		//   whether read-data is available, which it will not
		//   be, so the first two bytes are zeros
		//
		// * JTAG-to-Avalon-ST IDLE codes (4Ah)

		// * the JTAG-to-Avalon-ST encoded bytes-to-packets
		//   response data, i.e., nominally
		//
		// Bytes  Value  Description
		// -----  -----  -----------
		//  [0]    0x7C  Channel
		//  [1]    0x00  Channel number
		//  [2]    0x7A  Start-of-packet
		//  [3]          Read-data[7:0]
		//  [4]          Read-data[15:8]
		//  [5]          Read-data[23:16]
		//  [6]    0x7B  End-of-packet
		//  [7]          Read-data[31:24]
		//
		// But if any of the data bytes use a special code used in either
		// the JTAG-to-Avalon-ST or by the bytes-to-packet protocol, then they
		// are escaped and the byte-stream contains the ESCAPE code followed
		// by the character XORed with the escape mask.
		//
		// Find the channel code
		rdindex = 0;
		while ((rdindex < 256) && (rdbytes[rdindex++] != 'h7C));
		assert (rdindex < 256) else $error("Channel code not detected!");

		// Check the first couple of bytes are correct
		assert (rdbytes[rdindex++] == 0)    else $error("Channel number error!");
		assert (rdbytes[rdindex++] == 'h7A) else $error("Start-of-packet code error!");

		// Parse the data bytes
		byteindex = 0;
		data = 0;
		while (byteindex < 4)
		begin

			// JTAG protocol escape code?
			if (rdbytes[rdindex] == 'h4D)
			begin
				rdindex++;
				data = data | ((rdbytes[rdindex++] ^ 'h20) << 8*byteindex);
			end

			// Packet protocol escape code?
			else if (rdbytes[rdindex] == 'h7D)
			begin
				rdindex++;
				data = data | ((rdbytes[rdindex++] ^ 'h20) << 8*byteindex);
			end

			// Just data
			else
			begin
				data = data | (rdbytes[rdindex++] << 8*byteindex);
			end
			byteindex++;

			// Check the end-of-packet
			if (byteindex == 3)
			begin
				assert (rdbytes[rdindex++] == 'h7B) else $error("End-of-packet code error!");
			end
		end
	end
	endtask

	// ------------------------------------------------------------
	// Avalon-MM master write 32-bit multiple
	// * data is a dynamically created array of 32-bit values
	//   passed in by the caller
	// ------------------------------------------------------------
	task automatic master_write_32m (
	// ------------------------------------------------------------
		const ref logic [31:0] addr,
		const ref logic [31:0] data[]
	);
		// --------------------------------------------------------
		// Local variables
		// --------------------------------------------------------
		//
		// Input data length
		int data_len = data.size();
		int size = 4*data_len;

		 // Transaction byte length
		 // * 8-bytes header plus 4-bytes per data element
		int txbytes_len = 8 + 4*data_len;
		logic [7:0] txbytes[] = new[txbytes_len];

		// Packet to transaction length and JTAG stream byte length
		// * 2-bytes channel + 1-byte SOP + 1-byte EOP +
		//   two times the transaction bytes (incase they
		//   are all escaped)
		int pkbytes_len = 4 + 2*txbytes_len;
		logic [7:0] pkbytes[] = new[pkbytes_len];

		// The length of these vectors is determined by the
		// scan length
		logic [7:0] wrbytes[];
		logic [7:0] rdbytes[];

		// Byte stream indices
		int txindex;
		int pkindex;
		int wrindex;
		int rdindex;
		int byteindex;
		int scanlength;

		// 32-bit data word
		logic [31:0] word;

		// JTAG byte stream header
		logic [15:0] header;

	begin
		// The transaction packet supports a byte size
		// from 0 to FFFCh for 32-bit transactions
		assert (size <= 'hFFFC) else
			$error("Error: the data vector is too big!");

		// Put the JTAG-to-Avalon-ST bridge in data mode
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;

		// Virtual JTAG capture-DR state
		`VTAP.enter_cdr_state;

		// Avalon-MM transaction bytes format
		//
		//  Byte   Value  Description
		// ------  -----  -----------
		//    [0]  0x00   Transaction code = write, with increment
		//    [1]  0x00   Reserved
		//  [3:2]  0x0004 16-bit size (big-endian byte order)
		//  [7:4]  32-bit address (big-endian byte order)
		// [11:8]  32-bit data (little-endian byte order)
		//
		txbytes[0]  = 4;           // Write, with increment
		txbytes[1]  = 0;           // Reserved
		txbytes[2]  = size[15:8];  // 16-bit size (big-endian)
		txbytes[3]  = size[7:0];
		txbytes[4]  = addr[31:24]; // Address (big-endian)
		txbytes[5]  = addr[23:16];
		txbytes[6]  = addr[15: 8];
		txbytes[7]  = addr[ 7: 0];

		// Add the data bytes in little-endian format
		txindex = 8;
		foreach (data[i])
		begin
			word = data[i];
			txbytes[txindex++] = word[ 7: 0];
			txbytes[txindex++] = word[15: 8];
			txbytes[txindex++] = word[23:16];
			txbytes[txindex++] = word[31:24];
		end

		// Encode the transaction to packet bytes format
		//
		// Byte    Value  Description
		// -----   -----  ----------
		//  [0]    0x00   Channel number
		//  [1]    0x7A   Start-of-packet
		//  [X:2]         Transaction bytes with escape codes
		//         0x7B   End-of-packet
		//  [Y]           Last transaction byte (or escape code plus byte)
		//
		pkbytes[0]  = 'h7C;  // Channel
		pkbytes[1]  = 'h00;
		pkbytes[2]  = 'h7A;  // SOP

		// Insert the transaction bytes, escaping as needed
		pkindex = 3;
		for (int i = 0; i < txindex; i++)
		begin
			// Insert the end-of-packet (before the last data/escaped data)
			if (i == txindex-1)
			begin
				pkbytes[pkindex++] = 'h7B;
			end

			// Escape code required?
			if ((txbytes[i] >= 'h7A) && (txbytes[i] <= 'h7D))
			begin
				// Insert the escape code and modified byte
				pkbytes[pkindex++] = 'h7D;
				pkbytes[pkindex++] = txbytes[i] ^ 'h20;
			end
			else
			begin
				pkbytes[pkindex++] = txbytes[i];
			end
		end

		// JTAG byte-stream scan-length
		// * add 2-bytes for the header and 8-bytes for the response
		scanlength = $ceil((pkindex + 2 + 8)/256.0)*256.0;

		// Encode the 16-bit JTAG byte-stream header
		// * write length = read length = scan length
		header = 16'hFC00 | (scanlength/256-1) & 10'h3FF;

		$display("scanlength = %0d", scanlength);
		$display("header = %.4X", header);

		// Create the JTAG byte stream vectors
		wrbytes = new[scanlength];
		rdbytes = new[scanlength];

		// Encode the packet bytes in JTAG-to-Avalon-ST format
		//
		// Byte    Value  Description
		// -----   -----  ----------
		//  [1:0]  XXXXh  JTAG-to-Avalon-ST packet header (256-bytes)
		// [X-1:2]        Transaction bytes with escape codes
		// [255:X]        JTAG-to-Avalon-ST IDLE codes
		//
		wrbytes[0]  = header[7:0];  // header (16-bit little-endian)
		wrbytes[1]  = header[15:8];

		// Insert the transaction bytes, escaping as needed
		wrindex = 2;
		for (int i = 0; i < pkindex; i++)
		begin
			// Escape code required?
			if ((pkbytes[i] == 'h4A) || (pkbytes[i] == 'h4D))
			begin
				// Insert the escape code and modified byte
				wrbytes[wrindex++] = 'h4D;
				wrbytes[wrindex++] = pkbytes[i] ^ 'h20;
			end
			else
			begin
				wrbytes[wrindex++] = pkbytes[i];
			end
		end

		// Fill the remainder of the transaction with JTAG IDLE codes
		for (int i = wrindex; i < scanlength; i++)
			wrbytes[i] = 'h4A;

		// Send the bytes and capture the response bytes
		for (int i = 0; i < scanlength; i++)
		begin
			`VTAP.shift_one_byte(wrbytes[i],  rdbytes[i]);
		end

		// Parse and check the response data
		//
		// Bytes  Value  Description
		// -----  -----  -----------
		//  [0]    0x7C  Channel
		//  [1]    0x00  Channel number
		//  [2]    0x7A  Start-of-packet
		//  [3]    0x80  Transaction code with MSB set
		//  [4]    0x00  Reserved
		//  [5]    0x00  Size[15:8]
		//  [6]    0x7B  End-of-packet
		//  [7]    0x04  Size[7:0]
		//
		// Since the response data for a write does not contain
		// encoded characters, they are not checked (see the
		// master_read_32 task for how its done).
		//
		// Find the channel code
		// (the beginning of the response packet)
		rdindex = 0;
		while ((rdindex < scanlength) && (rdbytes[rdindex++] != 'h7C));
		assert (rdindex < scanlength) else $error("Channel code not detected!");

		// Check all the response bytes
		assert (rdbytes[rdindex++] == 0)    else $error("Channel number error!");
		assert (rdbytes[rdindex++] == 'h7A) else $error("Start-of-packet code error!");
		assert (rdbytes[rdindex++] == 'h84) else $error("Transaction code error!");
		assert (rdbytes[rdindex++] == 'h00) else $error("Reserved code error!");
		assert (rdbytes[rdindex++] == size[15:8]) else $error("Size MSBs error!");
		assert (rdbytes[rdindex++] == 'h7B) else $error("End-of-packet code error!");
		assert (rdbytes[rdindex++] == size[7:0]) else $error("Size LSBs error!");

		// Virtual JTAG Exit1-DR and then Update-DR state
		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;

		// Delete the dynamic arrays
		txbytes.delete();
		pkbytes.delete();
		wrbytes.delete();
		rdbytes.delete();
	end
	endtask

	// ------------------------------------------------------------
	// Avalon-MM master write 32-bit multiple
	// * the data is returned as a dynamically created array
	//   of 32-bit values
	// * its the caller's responsibility to delete the data
	// ------------------------------------------------------------
	task automatic master_read_32m (
	// ------------------------------------------------------------
		const ref logic [31:0] addr,
		ref logic [31:0] data[],
		input int data_len
	);

		// --------------------------------------------------------
		// Local variables
		// --------------------------------------------------------
		//
		 // Transaction byte length (fixed for a read)
		logic [7:0] txbytes[8];

		// Number of bytes to read
		int size = 4*data_len;

		// Packet to transaction length
		// * 2-bytes channel + 1-byte SOP + 1-byte EOP +
		//   two times the transaction bytes (incase they
		//   are all escaped)
		//
		int pkbytes_len = 4 + 2*8;
		logic [7:0] pkbytes[] = new[pkbytes_len];

		// The length of these vectors is determined by the
		// scan length
		logic [7:0] wrbytes[];
		logic [7:0] rdbytes[];

		// Byte stream indices
		int txindex;
		int pkindex;
		int wrindex;
		int rdindex;
		int byteindex;
		int scanlength;

		// JTAG byte stream header
		logic [15:0] header;

	begin

		// Put the JTAG-to-Avalon-ST bridge in data mode
		@(posedge `VTAP.tck);
		`VTAP.enter_data_mode;

		// Virtual JTAG capture-DR state
		`VTAP.enter_cdr_state;

		// Avalon-MM transaction bytes format
		//
		//  Byte   Value  Description
		// ------  -----  -----------
		//    [0]  0x14   Transaction code = read, with increment
		//    [1]  0x00   Reserved
		//  [3:2]  0x0004 16-bit size (big-endian byte order)
		//  [7:4]  32-bit address (big-endian byte order)
		//
		// The transaction code could be read without increment,
		// however, read with increment is used, as this matches
		// the SignalTap II traces.
		//
		txbytes[0]  = 'h14;        // Read, with increment
		txbytes[1]  = 0;           // Reserved
		txbytes[2]  = size[15:8];  // 16-bit size (big-endian)
		txbytes[3]  = size[7:0];
		txbytes[4]  = addr[31:24]; // Address (big-endian)
		txbytes[5]  = addr[23:16];
		txbytes[6]  = addr[15: 8];
		txbytes[7]  = addr[ 7: 0];

		// Encode the transaction to packet bytes format
		//
		// Byte    Value  Description
		// -----   -----  ----------
		//  [0]    0x00   Channel number
		//  [1]    0x7A   Start-of-packet
		//  [X:2]         Transaction bytes with escape codes
		//         0x7B   End-of-packet
		//  [Y]           Last transaction byte (or escape code plus byte)
		//
		pkbytes[0]  = 'h7C;  // Channel
		pkbytes[1]  = 'h00;
		pkbytes[2]  = 'h7A;  // SOP

		// Insert the transaction bytes, escaping as needed
		pkindex = 3;
		for (int i = 0; i < 8; i++)
		begin
			// Insert the end-of-packet (before the last data/escaped data)
			if (i == 7)
			begin
				pkbytes[pkindex++] = 'h7B;
			end

			// Escape code required?
			if ((txbytes[i] >= 'h7A) && (txbytes[i] <= 'h7D))
			begin
				// Insert the escape code and modified byte
				pkbytes[pkindex++] = 'h7D;
				pkbytes[pkindex++] = txbytes[i] ^ 'h20;
			end
			else
			begin
				pkbytes[pkindex++] = txbytes[i];
			end
		end

		// JTAG byte-stream scan-length
		// * add 2-bytes for the header and 2*size-bytes for the
		//   response (the factor 2 accounts for ESCAPE codes)
		scanlength = $ceil((pkindex + 2 + 2*size)/256.0)*256.0;

		// Encode the 16-bit JTAG byte-stream header
		// * write length = read length = scan length
		header = 16'hFC00 | (scanlength/256-1) & 10'h3FF;

		$display("scanlength = %0d", scanlength);
		$display("header = %.4X", header);

		// Create the JTAG byte stream vectors
		wrbytes = new[scanlength];
		rdbytes = new[scanlength];

		// Encode the packet bytes in JTAG-to-Avalon-ST format
		//
		// Byte    Value  Description
		// -----   -----  ----------
		//  [1:0]  XXXXh  JTAG-to-Avalon-ST packet header (256-bytes)
		// [X-1:2]        Transaction bytes with escape codes
		// [255:X]        JTAG-to-Avalon-ST IDLE codes
		//
		wrbytes[0]  = header[7:0];  // header (16-bit little-endian)
		wrbytes[1]  = header[15:8];

		// Insert the transaction bytes, escaping as needed
		wrindex = 2;
		for (int i = 0; i < pkindex; i++)
		begin
			// Escape code required?
			if ((pkbytes[i] == 'h4A) || (pkbytes[i] == 'h4D))
			begin
				// Insert the escape code and modified byte
				wrbytes[wrindex++] = 'h4D;
				wrbytes[wrindex++] = pkbytes[i] ^ 'h20;
			end
			else
			begin
				wrbytes[wrindex++] = pkbytes[i];
			end
		end

		// Fill the remainder of the transaction with JTAG IDLE codes
		for (int i = wrindex; i < scanlength; i++)
			wrbytes[i] = 'h4A;

		// Send the bytes and capture the response bytes
		for (int i = 0; i < scanlength; i++)
		begin
			`VTAP.shift_one_byte(wrbytes[i],  rdbytes[i]);
		end

		// The assumption is that the read bytes have all
		// been read. This is a valid assumption for this
		// testbench. In reality, the received bytes should
		// be parsed while being received so that the
		// end-of-packet can be detected.

		// Virtual JTAG Exit1-DR and then Update-DR state
		`VTAP.enter_e1dr_state;
		`VTAP.enter_udr_state;

		// Parse and extract the read data
		//
		// The read byte stream consists of;
		// * the 16-bit read data header (the LSB indicates
		//   whether read-data is available, which it will not
		//   be, so the first two bytes are zeros
		//
		// * JTAG-to-Avalon-ST IDLE codes (4Ah)

		// * the JTAG-to-Avalon-ST encoded bytes-to-packets
		//   response data, i.e., nominally
		//
		// Bytes  Value  Description
		// -----  -----  -----------
		//  [0]    0x7C  Channel
		//  [1]    0x00  Channel number
		//  [2]    0x7A  Start-of-packet
		//  [3]          Read-data[7:0]
		//  [4]          Read-data[15:8]
		//  [5]          Read-data[23:16]
		//  [6]    0x7B  End-of-packet
		//  [7]          Read-data[31:24]
		//
		// But if any of the data bytes use a special code used in either
		// the JTAG-to-Avalon-ST or by the bytes-to-packet protocol, then they
		// are escaped and the byte-stream contains the ESCAPE code followed
		// by the character XORed with the escape mask.
		//
		// Find the channel code
		rdindex = 0;
		while ((rdindex < 256) && (rdbytes[rdindex++] != 'h7C));
		assert (rdindex < 256) else $error("Channel code not detected!");

		// Check the first couple of bytes are correct
		assert (rdbytes[rdindex++] == 0)    else $error("Channel number error!");
		assert (rdbytes[rdindex++] == 'h7A) else $error("Start-of-packet code error!");

		// Parse the data bytes
		data = new[data_len];
		foreach (data[i])
		begin
			byteindex = 0;
			data[i] = 0;
			while (byteindex < 4)
			begin

				// JTAG protocol escape code?
				if (rdbytes[rdindex] == 'h4D)
				begin
					rdindex++;
					data[i] = data[i] | ((rdbytes[rdindex++] ^ 'h20) << 8*byteindex);
				end

				// Packet protocol escape code?
				else if (rdbytes[rdindex] == 'h7D)
				begin
					rdindex++;
					data[i] = data[i] | ((rdbytes[rdindex++] ^ 'h20) << 8*byteindex);
				end

				// Just data
				else
				begin
					data[i] = data[i] | (rdbytes[rdindex++] << 8*byteindex);
				end
				byteindex++;

				// Check the end-of-packet
				if ((i == data_len-1) && (byteindex == 3))
				begin
					assert (rdbytes[rdindex++] == 'h7B) else $error("End-of-packet code error!");
				end
			end
		end
	end
	endtask

endmodule



