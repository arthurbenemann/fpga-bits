`define BENCH

module bench();
   reg CLK;

   reg miso = 0;
   wire mosi,ce,sclk;
   wire [95:0] data_in;

   SPI psram(
      .clk(CLK),
      .miso(mosi),
      .mosi(mosi),
      .ce(ce),
      .sclk(sclk),
      .rdata(data_in)
   );   

   initial begin
      CLK = 1'b0;
      forever #1 CLK = ~CLK;
   end
 
   initial begin
      #380
      $dumpfile("bench.vcd");
      $dumpvars(0, bench);

      #1000 $finish();
   end

endmodule   
   