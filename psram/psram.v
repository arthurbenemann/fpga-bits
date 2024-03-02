/*
    PSRAM test
*/


module SOC (
        input  CLK,        
        input  RESET,      
        output [4:0] LEDS, 
        output TXD,
        input P1A4,
        input P1A3
    );    
    assign LEDS = 1;
    
    PLL pll1(.clkin(CLK),.clkout(clk));
    wire clk;

	reg [7:0] tx_data = "A";

    wire uart_ready;
    
    corescore_emitter_uart #(
        .clk_divider(200)     // Fin=50Mhz, baud =50Mhz/200 = 250kbaud
    ) UART(
        .i_clk(clk),
        .i_data(tx_data),
        .o_ready(uart_ready),
        .o_uart_tx(TXD)			       
    );
    
endmodule


module PLL(
    input clkin,
    output clkout
);
    SB_PLL40_PAD pll ( // PLL Fin=12Mhz, Fout=50Mhz
        .PACKAGEPIN(clkin), .PLLOUTCORE(clkout),
        .RESETB(1'b1), .BYPASS(1'b0)
    );
    defparam pll.FEEDBACK_PATH="SIMPLE";
    defparam pll.PLLOUT_SELECT="GENCLK";
    defparam pll.DIVR = 4'b0000;
    defparam pll.DIVF = 7'b1000010;
    defparam pll.DIVQ = 3'b100;
    defparam pll.FILTER_RANGE = 3'b001;        
        
endmodule


// https://github.com/olofk/corescore/, Apache-2.0 license
module corescore_emitter_uart #(parameter clk_divider=12)(
   input wire 	    i_clk,
   input wire [7:0] i_data,
   output reg 	    o_ready,
   output wire 	    o_uart_tx
);
   localparam START_VALUE = clk_divider-2;   
   localparam WIDTH = $clog2(START_VALUE);   
   reg [WIDTH:0]  cnt = 0;   
   reg [9:0] 	    data;

   assign o_uart_tx = data[0] | !(|data);

   always @(posedge i_clk) begin
            if (cnt[WIDTH] & !(|data)) begin
                  o_ready <= 1'b1;
            end else if (o_ready) begin
                  o_ready <= 1'b0;
            end

            cnt <= (o_ready | cnt[WIDTH])? {1'b0,START_VALUE[WIDTH-1:0]} : cnt-1;
            
            if (cnt[WIDTH])
                  data <= {1'b0, data[9:1]};
            else if (o_ready)
                  data <= {1'b1, i_data, 1'b0};

   end
endmodule
