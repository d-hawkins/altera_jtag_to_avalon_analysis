// ----------------------------------------------------------------
// bemicro_sdk.sv
//
// 1/31/2012 D. W. Hawkins (dwh@caltech.edu)
//
// BeMicro-SDK JTAG-to-Avalon-MM example
// (for SignalTap II trace capture).
//
// This example shows the basics of using the JTAG-to-Avalon-MM
// component. The SystemConsole master and bytestream procedures
// can be used to generate Avalon-MM activity.
//
// The JTAG-to-Avalon-MM bridge implements a 32-bit Avalon-MM
// interface and has a single GPIO bit that is used as a reset
// request. The logic below implements a 32-bit Avalon-MM slave
// register.
//
// The 8 LEDs on the BeMicro are used for display:
//
// LED[5:0] = 6-bits of the 32-bit Avalon-MM slave register
// LED[6]   = resetrequest signal
// LED[7]   = blinks (to show the design is loaded and running)
//
// ----------------------------------------------------------------
// Notes:
// ------
//
// 1, Quartus II synthesis results (2/8/2012):
//
//    For Quartus versions 11.0sp1
//    (full subscription edition)
//
//    ----------------------------------------------------------
//   |   avalon_mm    | sld_hub  | user logic ||  total logic   |
//   |----------------|----------|------------||----------------|
//   |                |          |            ||                |
//   |   848 LCs      |  99 LCs  |  113 LCs   ||   1060 LCs     |
//   | + 512-bits RAM |          |            || + 512-bits RAM |
//   |                |          |            ||                |
//    ----------------------------------------------------------
//
//    The RAM use is due to the 64 x 8-bit FIFO in the
//    host-to-device data path of the JTAG-to-Avalon-MM master.
//
//    Quartus 10.1 uses 2 LCs less for the avalon_mm interface.
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
	// The synthesis attributes are to allow SignalTap II probing
	//
	logic [WIDTH-1:0] count;
	logic [31:0] mm_addr      /* synthesis keep */;
	logic [ 3:0] mm_byteen    /* synthesis keep */;
	logic        mm_read      /* synthesis keep */;
	logic        mm_write     /* synthesis keep */;
	logic [31:0] mm_rddata;
	logic [31:0] mm_wrdata    /* synthesis keep */;
	logic        mm_rdvalid;
	logic        mm_wait;
	logic        resetrequest /* synthesis keep */;

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
	// JTAG-to-Avalon-MM bridge
	// ------------------------------------------------------------
	//
	altera_jtag_avalon_master u2 (
		.clk(clkin_50MHz),
		.reset_n(cpu_rstN),

		// Avalon-MM master
		.read_from_the_altera_jtag_avalon_master_packets_to_transactions_converter(mm_read),
		.write_from_the_altera_jtag_avalon_master_packets_to_transactions_converter(mm_write),
		.byteenable_from_the_altera_jtag_avalon_master_packets_to_transactions_converter(mm_byteen),
		.address_from_the_altera_jtag_avalon_master_packets_to_transactions_converter(mm_addr),
		.readdata_to_the_altera_jtag_avalon_master_packets_to_transactions_converter(mm_rddata),
		.writedata_from_the_altera_jtag_avalon_master_packets_to_transactions_converter(mm_wrdata),
		.readdatavalid_to_the_altera_jtag_avalon_master_packets_to_transactions_converter(mm_rdvalid),
		.waitrequest_to_the_altera_jtag_avalon_master_packets_to_transactions_converter(mm_wait),

		// Reset request
		.resetrequest_from_the_altera_jtag_avalon_master_jtag_interface(resetrequest)

	);

	// ------------------------------------------------------------
	// Avalon-MM data register
	// ------------------------------------------------------------
	//
	// An Avalon-MM register
	//
	// * writes occur only for accesses to address 11223344h
	//    - the JTAG byte-stream protocol transmits the address
	//      bytes in big-endian format, i.e., 11h, 22h, 33h, 44h
	//    -,Avalon-MM addresses must be 32-bit aligned
	//
	// * the register is readable from any address
	//
	always_ff @(posedge clkin_50MHz or negedge cpu_rstN)
	begin
		if (~cpu_rstN)
		begin
			mm_wait    <= 1;
			mm_rdvalid <= 0;
			mm_rddata  <= '0;
		end
		else
		begin
			// Always ready
			mm_wait <= 0;

			// Single pipeline delay
			mm_rdvalid <= mm_read;

			// Write
			if (mm_write)
				if (mm_addr == 32'h11223344)
				begin
					if (mm_byteen[0])
						mm_rddata[7:0]   <= mm_wrdata[7:0];
					if (mm_byteen[1])
						mm_rddata[15:8]  <= mm_wrdata[15:8];
					if (mm_byteen[2])
						mm_rddata[23:16] <= mm_wrdata[23:16];
					if (mm_byteen[3])
						mm_rddata[31:24] <= mm_wrdata[31:24];
				end
		end
	end

	// ------------------------------------------------------------
	// LED output
	// ------------------------------------------------------------
	//
	// The LEDs turn on for low outputs.
	//
	assign led = {~count[WIDTH-1], ~resetrequest, ~mm_rddata[5:0]};

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