`define BENCH

module bench();
   reg CLK;
   reg uart_ready;
   wire [7:0] tx_data;


   RegisterToUART dut(
      .clk(CLK),          
      .data(96'h12_345678_9abc_def123456789),  
      .tx_data(tx_data),
      .uart_ready(uart_ready)
   );

   initial begin
      CLK = 1'b0;
      forever #1 CLK = ~CLK;
   end

 
   initial begin
      uart_ready = 1'b0;
      forever begin
         #100 $write("%c",tx_data);
         #1 uart_ready =1'b1;
         #1 uart_ready =1'b0;
      end
   end
endmodule   
   