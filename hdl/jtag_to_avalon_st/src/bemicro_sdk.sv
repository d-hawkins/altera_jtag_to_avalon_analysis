// ----------------------------------------------------------------
// bemicro_sdk.sv
//
// 1/27/2012 D. W. Hawkins (dwh@caltech.edu)
//
// BeMicro-SDK JTAG-to-Avalon-ST example
// (for SignalTap II trace capture).
//
// This example shows the basics of using the JTAG-to-Avalon-ST
// component. The SystemConsole bytestream procedures can be
// used to generate Avalon-ST activity.
//
// The JTAG-to-Avalon-ST bridge has an 8-bit Avalon-ST stream,
// and has a single GPIO bit that is used as a reset request
// in SOPC/Qsys systems. The Avalon-ST data is captured into
// an 8-bit register each time Avalon-ST valid asserts.
// Avalon-ST write data is looped back as Avalon-ST read data.
//
// The 8 LEDs on the BeMicro are used for display:
//
// LED[5:0] = 6-bits of the 8-bit Avalon-ST data register
// LED[6]   = resetrequest signal
// LED[7]   = blinks (to show the design is loaded and running)
//
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
//       --------------------------------------------------
//      | avalon_st | sld_hub  | user logic || total logic |
//      |-----------|----------|------------||-------------|
//      |           |          |            ||             |
//      |  426 LCs  |  99 LCs  |   51 LCs   ||  576 LCs    |
//      |           |          |            ||             |
//       --------------------------------------------------
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

	// Loopback control (set to 1 to loopback Avalon-ST data)
	localparam USE_LOOPBACK = 1;

	// ------------------------------------------------------------
	// Internal signals
	// ------------------------------------------------------------
	//
	logic [WIDTH-1:0] count;
	logic [7:0] source_data;
	logic       source_ready;
	logic       source_valid;
	logic [7:0] sink_data;
	logic       sink_valid;
	logic       sink_ready;
	logic       resetrequest;

	/* Use a synthesis attribute to keep all 8-bits for
	 * SignalTap II probing, without it bits 6+7 are eliminated.
	 * The bits are fanout free, so 'synthesis preserve' does not
	 * work (see Quartus help for details).
	 */
	logic [7:0] data /* synthesis noprune */;

	/* Write data counter */
	logic [15:0] write_count /* synthesis noprune */;

	// ------------------------------------------------------------
	// LED counter
	// ------------------------------------------------------------
	//
	always_ff @ (posedge clkin_50MHz, negedge cpu_rstN)
	if (~cpu_rstN)
		count <= '0;
	else
		count <= count + 1'b1;

	// ------------------------------------------------------------
	// Write data counter
	// ------------------------------------------------------------
	//
	// Probe this counter with SignalTap II to confirm the number
	// of transfers per bytestream transaction.
	//
	always_ff @ (posedge clkin_50MHz, negedge cpu_rstN)
	if (~cpu_rstN)
		write_count <= '0;
	else
		if (source_valid == 1)
			write_count <= write_count + 1'b1;

	// ------------------------------------------------------------
	// JTAG-to-Avalon-ST bridge
	// ------------------------------------------------------------
	//
	altera_avalon_st_jtag_interface u1 (
		.clk(clkin_50MHz),
		.reset_n(cpu_rstN),

		// Avalon-ST source/sink
		.source_ready,
		.source_data,
		.source_valid,
		.sink_data,
		.sink_valid,
		.sink_ready,

		// Reset request
		.resetrequest
	);

	// ------------------------------------------------------------
	// Avalon-ST loopback
	// ------------------------------------------------------------
	//
	// The default implementation is to loopback the Avalon-ST
	// interface. During hardware/SignalTap II tracing
	// tests, it can be convenient to disable the loopback.
	//
	generate
		if (USE_LOOPBACK == 1)
			begin
				assign source_ready = sink_ready;
				assign sink_valid   = source_valid;
				assign sink_data    = source_data;
			end
		else
			begin
				// Accept all write data (which updates the LEDs)
				assign source_ready = 1'b1;

				// Never any read data
				assign sink_valid  = 1'b0;
				assign sink_data  = '0;
			end
   endgenerate

	// ------------------------------------------------------------
	// Avalon-ST data register
	// ------------------------------------------------------------
	//
	// Capture the source data
	always @(posedge clkin_50MHz or negedge cpu_rstN)
	begin
		if (~cpu_rstN)
			data <= '0;
		else
			if (source_valid == 1)
				data <= source_data;
	end

	// ------------------------------------------------------------
	// LED output
	// ------------------------------------------------------------
	//
	// The LEDs turn on for low outputs.
	//
	assign led = {~count[WIDTH-1], ~resetrequest, ~data[5:0]};

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