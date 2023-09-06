   module top (
       input  CLK,
       input  BTN_N,BTN1,
       output LED1, LED2, LED3, LED4, LED5
   );

   wire clkd;
   wire [4:0] LEDS;

   assign {LED1, LED2, LED3, LED4, LED5} = LEDS;
   
   reg [4:0] count = 0;
   assign LEDS = count;

   Clock_divider clkdiv(.clock_in(CLK), .clock_out(clkd));
   
   always @(posedge clkd) begin
      count <= count + 1;
   end


   endmodule

module Clock_divider(
	input clock_in, // input clock on FPGA
	output reg clock_out, // output clock after dividing the input clock by divisor
);

	reg [31:0] clkdiv = 0;
	reg clock_out = 0;

	// Synchronous logic
	always @(posedge clock_in) begin
		// Clock divider pulse generator
		if (clkdiv == 6000000) begin
			clkdiv <= 0;
			clock_out <= 1;
		end else begin
			clkdiv <= clkdiv + 1;
			clock_out <= 0;
		end

	end
endmodule
