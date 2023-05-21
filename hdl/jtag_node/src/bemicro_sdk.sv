// ----------------------------------------------------------------
// bemicro_sdk.sv
//
// 1/27/2012 D. W. Hawkins (dwh@caltech.edu)
//
// BeMicro-SDK JTAG node example (for SignalTap II trace capture).
//
// This example shows the basics of using the JTAG SLD node
// Virtual Instruction Register for decoding data registers.
// The data registers are written and read using the serial
// TDI and TDO signals. The Virtual JTAG on-hot state status
// bits are used to control loading, shifting, and updating of
// data.
//
// The 8 LEDs on the BeMicro are used for display:
//
// LED[3:0] = 4-bits of the 8-bit data register
// LED[6:4] = 3-bits Virtual Instruction Register (IR)
// LED[7]   = blinks (to show the design is loaded and running)
//
// ----------------------------------------------------------------
// Notes:
// ------
//
// 1, Quartus II synthesis results (2/8/2012):
//
//    For Quartus versions 10.1 and 11.0sp1
//    (full subscription editions)
//
//       -------------------------------------------------
//      | sld_node | sld_hub  | user logic || total logic |
//      |----------|----------|------------||-------------|
//      |          |          |            ||             |
//      |   1 LC   |  99 LCs  |   49 LCs   ||  149 LCs    |
//      |          |          |            ||             |
//       -------------------------------------------------
//
// ----------------------------------------------------------------

module bemicro_sdk
	(
		// --------------------------------------------------------
		// Clock
		// --------------------------------------------------------
		//
		// 50MHz oscillator
		input  logic       clkin_50MHz,

		// --------------------------------------------------------
		// User I/O
		// --------------------------------------------------------
		//
		// Push buttons
		input  logic       cpu_rstN,
		input  logic       pb,

		// Switches (the PCB has the switch numbers)
		input  logic [2:1] sw,

		// LEDs
		output logic [7:0] led,

		// --------------------------------------------------------
		// SPI temperature sensor
		// --------------------------------------------------------
		//
		output logic       spi_sck,
		output logic       spi_csN,
		output logic       spi_mosi,
		input  logic       spi_miso,

		// --------------------------------------------------------
		// Ethernet PHY
		// --------------------------------------------------------
		//
		// I2C interface
		output logic       eth_mdc,
		inout  logic       eth_mdio,

		// PHY interface
		input  logic       eth_tx_clk,
		input  logic       eth_rx_clk,
		output logic       eth_rstN,
		input  logic       eth_col,
		input  logic       eth_crs,
		input  logic       eth_rx_er,
		input  logic       eth_rx_dv,
		output logic       eth_tx_en,
		output logic [3:0] eth_txd,
		input  logic [3:0] eth_rxd,

		// --------------------------------------------------------
		// MicroSD card slot
		// --------------------------------------------------------
		//
		output logic       sd_clk,
		output logic       sd_cmd,
		inout  logic [3:0] sd_dat,

		// --------------------------------------------------------
		// Mobile DDR memory
		// --------------------------------------------------------
		//
		// Differential clock
		output logic        ddr_ck_p,
		output logic        ddr_ck_n,

		// Controls
		output logic        ddr_csN,
		output logic        ddr_rasN,
		output logic        ddr_casN,
		output logic        ddr_weN,
		output logic        ddr_cke,

		// Data mask (write byte-enable)
		output logic [1:0]  ddr_dqm,

		// Data strobe
		inout  logic [1:0]  ddr_dqs,

		// Address outputs
		output logic [13:0] ddr_a,
		output logic  [1:0] ddr_ba,

		// Bidirectional 16-bit data bus
		inout  logic [15:0] ddr_dq,

		// --------------------------------------------------------
		// GPIO (expansion connector)
		// --------------------------------------------------------
		//
		// Reset from the expansion board
		input  logic        exp_rstN,

		// Expansion board present (when high)
		input  logic        exp_present,

		// GPINs (with external pull-downs)
		input  logic  [3:0] exp_gpin,

		// GPIOs
		inout  logic [54:4] exp_gpio

	);

	// ------------------------------------------------------------
	// Local parameters
	// ------------------------------------------------------------
	//
	// Counter width required to blink the LED MSB
	//
	localparam real CLK_FREQ = 50.0e6;
	localparam real BLINK_PERIOD = 0.5;
	localparam integer COUNT = CLK_FREQ*BLINK_PERIOD;
	localparam integer WIDTH = $clog2(COUNT);

	// ------------------------------------------------------------
	// Internal signals
	// ------------------------------------------------------------
	//
	logic [WIDTH-1:0] count;
	logic [2:0] ir_out;
	logic tdo;
	logic [2:0] ir_in;
	logic tck;
	logic tdi;
	logic vs_cdr;
	logic vs_sdr;
	logic vs_e1dr;
	logic vs_udr;
	logic vs_e2dr;
	logic vs_pdr;
	logic vs_cir;
	logic vs_uir;
	logic [7:0] data_sr = '0;
	logic [7:0] data = '0;

	// ------------------------------------------------------------
	// Counter
	// ------------------------------------------------------------
	//
	always_ff @ (posedge clkin_50MHz, negedge cpu_rstN)
	if (~cpu_rstN)
		count <= '0;
	else
		count <= count + 1'b1;

	// ------------------------------------------------------------
	// JTAG node
	// ------------------------------------------------------------
	//
	altera_jtag_sld_node
		#(
			.TCK_FREQ_MHZ(6)
		)
		u1 (
		// SLD node inputs
    	.ir_out,
   		.tdo,

		// SLD node outputs
    	.ir_in,
    	.tck,
    	.tdi,
    	.virtual_state_cdr(vs_cdr),
    	.virtual_state_sdr(vs_sdr),
    	.virtual_state_e1dr(vs_e1dr),
    	.virtual_state_pdr(vs_pdr),
    	.virtual_state_e2dr(vs_e2dr),
    	.virtual_state_udr(vs_udr),
    	.virtual_state_cir(vs_cir),
    	.virtual_state_uir(vs_uir)
	);

	// LED output (the LEDs turn on for low outputs)
	assign led = {~count[WIDTH-1], ~ir_in, ~data[3:0]};

	// Switch read-back
	assign ir_out = {1'b0, sw};

	// ------------------------------------------------------------
	// JTAG serial data
	// ------------------------------------------------------------
	//
	// The following logic implements an 8-bit shift register
	// between the TDI and TDO JTAG signals. The Virtual JTAG
	// IR value is used for register decoding, and the state
	// bits are used to load the shift register, shift the
	// shift register, or load the parallel data register.
	//
	// The Virtual IR decode values are;
	//
	//   IR  Register
	//   --  --------
	//    0  Write to the 8-bit data register
	//    1  Read from the 8-bit data register
	//    2  Read from the 2-bit switch state
	//  3-7  Write data ignored, reads return zero
	//
	// Each JTAG data access is both a write and a read. Two
	// IR values are used for the 8-bit data register accesses
	// to allow the data register to be read without being
	// over-written. If this were a general purpose block of
	// registers, you could use the IR MSB to indicate read or
	// write, and the LSBs to indicate the selected register.
	//
	// ------------------------------------------------------------

	// Shift register
	always_ff @ (posedge tck)
	if (vs_cdr)
		// Load the shift register
		if (ir_in == 3'h1)
			// Parallel data register
			data_sr <= data;
		else if  (ir_in == 3'h2)
			// The switch state
			data_sr <= {6'h0, sw};
		else
			// Load zero (readback zero)
			data_sr <= 8'h0;
	else if (vs_sdr)
		// Shifting enabled
		data_sr <= {tdi, data_sr[7:1]};

	// Serial data output
	assign tdo = data_sr[0];

	// Parallel register
	// * load using virtual state e1dr, not udr, since udr
	//   is used to indicate that the update has occurred
	always_ff @ (posedge tck)
	if (vs_e1dr)
		if (ir_in == 3'h0)
			// Load the parallel data register
			data <= data_sr;

	// ============================================================
	// Unused outputs and bidirectional signals
	// ============================================================
	//
	// SPI temperature sensor
	assign spi_sck  = 0;
	assign spi_csN  = 1;
	assign spi_mosi = 'Z;

	// Ethernet PHY
	assign eth_mdc   = 0;
	assign eth_mdio  = 'Z;
	assign eth_rstN  = 0;
	assign eth_tx_en = 0;
	assign eth_txd   = '0;

	// MicroSD card slot
	assign sd_clk = 0;
	assign sd_cmd = 1;
	assign sd_dat = '1;

	// Mobile DDR memory
	assign ddr_ck_p = 0;
	assign ddr_ck_n = 1;
	assign ddr_csN  = 1;
	assign ddr_rasN = 1;
	assign ddr_casN = 1;
	assign ddr_weN  = 1;
	assign ddr_cke  = 0;
	assign ddr_dqm  = '1;
	assign ddr_dqs  = 'Z;
	assign ddr_a    = '0;
	assign ddr_ba   = '0;
	assign ddr_dq   = '0;

	// GPIOs
	assign exp_gpio = 'Z;

endmodule