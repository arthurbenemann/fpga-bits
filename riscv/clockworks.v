module Clockworks(
	input clock_in, // input clock on FPGA
	output clock_out // output clock after dividing the input clock by divisor
);


	reg [2:0] clkdiv = 0;

	assign clock_out = clock_in;

	// Synchronous logic
	always @(posedge clock_in) begin
		clkdiv <= clkdiv + 1;		
	end
endmodule
