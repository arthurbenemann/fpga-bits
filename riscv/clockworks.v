module Clockworks(
	input clock_in, // input clock on FPGA
	output clock_out, // output clock after dividing the input clock by divisor
	input  reset_ext, 
	output resetn
);

	// No clock divider
	//assign clock_out = clock_in;


	// PLL Fin=12Mhz, Fout=24Mhz
	SB_PLL40_PAD pll (
		.PACKAGEPIN(clock_in),
      	.PLLOUTCORE(clock_out),
      	.RESETB(1'b1),
      	.BYPASS(1'b0)
   	);
   	
	defparam pll.FEEDBACK_PATH="SIMPLE";		// FOUT = Fin* (DIVF+1)/( (DIVR+1)* 2^DIVQ) )
   	defparam pll.PLLOUT_SELECT="GENCLK";
	defparam pll.DIVR = 4'b0000;
    defparam pll.DIVF = 7'b1010100;
    defparam pll.DIVQ = 3'b110;
    defparam pll.FILTER_RANGE = 3'b001;
    defparam pll.DIVF = 7'b0111111;			
    defparam pll.DIVQ = 3'b101;				
    defparam pll.FILTER_RANGE = 3'b001;


	/* reset mechanism that resets the design during the first microseconds because
      reading in Ice40 BRAM during the first few microseconds returns garbage ! */
	reg [15:0]	reset_cnt = 0;
	assign resetn = &reset_cnt;


	 always @(posedge clock_out,negedge reset_ext) begin
	    if(!reset_ext) begin
	       reset_cnt <= 0;
		end else if(!resetn) begin
	       reset_cnt <= reset_cnt + reset_ext;
	    end
		//$display("reset_ext %d\t resetn %d\t resetcnt %d\n",reset_ext,resetn,reset_cnt);
	 end

endmodule
