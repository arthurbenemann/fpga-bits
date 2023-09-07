module Clockworks(
	input clock_in, // input clock on FPGA
	output reg clock_out // output clock after dividing the input clock by divisor
);

parameter SLOW = 4;

`ifdef BENCH
   localparam SLOW_bits = SLOW-4;
`else
   localparam SLOW_bits = SLOW;
`endif

	reg [SLOW_bits:0] clkdiv = 0;

	// Synchronous logic
	always @(posedge clock_in) begin
		// Clock divider pulse generator
		if (clkdiv[SLOW_bits]) begin
			clkdiv <= 0;
			clock_out <= 1;
		end else begin
			clkdiv <= clkdiv + 1;
			clock_out <= 0;
		end

	end
endmodule
