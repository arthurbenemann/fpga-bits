module SOC (
       input  CLK,        
       input  RESET,      
       output [4:0] LEDS, 
       input  RXD,        
       output TXD  
   );
  
   wire clkd;
   reg [4:0] count = 0;
   assign LEDS = count;
   assign TXD  = 1'b0; // not used for now

   Clock_divider clkdiv(.clock_in(CLK), .clock_out(clkd));
   
   always @(posedge clkd) begin
      count <= count + 1;
   end


endmodule

module Clock_divider(
	input clock_in, // input clock on FPGA
	output reg clock_out // output clock after dividing the input clock by divisor
);

   `define size 21

	reg [`size:0] clkdiv = 0;

	// Synchronous logic
	always @(posedge clock_in) begin
		// Clock divider pulse generator
		if (clkdiv[`size]) begin
			clkdiv <= 0;
			clock_out <= 1;
		end else begin
			clkdiv <= clkdiv + 1;
			clock_out <= 0;
		end

	end
endmodule
