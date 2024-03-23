`define BENCH

module bench();
   reg CLK;

   reg miso = 0;
   wire mosi,sclk;

   reg strb =0;
   reg [7:0] transmit = 8'b1100_1010;
   wire [7:0] received;
   wire valid;

   SPI psram(
      .clk(CLK),
      .miso(mosi),
      .mosi(mosi),
      .sclk(sclk),
      .strb(strb),
      .transmit(transmit),
      .received(received),
      .valid(valid)
   );   

   initial begin
      CLK = 1'b0;
      forever #1 CLK = ~CLK;
   end


   initial begin
      #11
      strb =1; 
      #2
      strb =0; 
   end
 
   initial begin
      $dumpfile("bench.vcd");
      $dumpvars(0, bench);
      #50 
      if(transmit!=received)
         $error("test failed, tx and rx data do not match");
      $finish();
   end
endmodule   
   