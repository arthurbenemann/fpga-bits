module Clockworks(
	input clock_in, // input clock on FPGA
	output clock_out, // output clock after dividing the input clock by divisor
	input reset_ext, 
	output resetn
);

	// No clock divider
	assign clock_out = clock_in;

	/* reset mechanism that resets the design during the first microseconds because
      reading in Ice40 BRAM during the first few microseconds returns garbage ! */
	reg [15:0]	reset_cnt = 0;
	assign resetn = &reset_cnt;


	 always @(posedge clock_in,negedge reset_ext) begin
	    if(!reset_ext) begin
	       reset_cnt <= 0;
		end else if(!resetn) begin
	       reset_cnt <= reset_cnt + reset_ext;
	    end
		//$display("reset_ext %d\t resetn %d\t resetcnt %d\n",reset_ext,resetn,reset_cnt);
	 end

endmodule
