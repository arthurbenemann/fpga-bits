`include "clockworks.v"

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

   Clockworks #(.SLOW(21))CW(.clock_in(CLK), .clock_out(clkd));
   
   always @(posedge clkd) begin
      count <= count + 1;
   end


endmodule
