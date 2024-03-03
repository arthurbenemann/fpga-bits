/*
    PSRAM test
*/


module SOC (
        input  CLK,        
        input  RESET,      
        output [4:0] LEDS, 
        output TXD,
        output RAM_SI,
        output RAM_CE_B,
        output RAM_CLK,
        input  RAM_SO
    );    
    assign LEDS = 1;
    
    PLL pll1(.clkin(CLK),.clkout(clk));
    wire clk;


    RegisterToUART r2u(.clk(clk),.data(spi_data),
                        .tx_data(tx_data),.uart_ready(uart_ready));
	wire [7:0] tx_data;
    wire uart_ready;
    
    corescore_emitter_uart #(
        .clk_divider(200)     // Fin=50Mhz, baud =50Mhz/200 = 250kbaud
    ) UART(
        .i_clk(clk),
        .i_data(tx_data),
        .o_ready(uart_ready),
        .o_uart_tx(TXD)			       
    );

    wire [95:0] spi_data;
    SPI psram(
        .clk(clk),
        .miso(RAM_SO),
        .mosi(RAM_SI),
        .ce(RAM_CE_B),
        .sclk(RAM_CLK),
        .data_in(spi_data),
    );   
endmodule

module SPI(
    input  clk,
    input  miso,
    output reg mosi,
    output reg ce, 
    output sclk,
    output reg [BIT_CNT:0] data_in
);

    // SPI controller
    localparam IDLE = 0;
    localparam TRANSFER = 1;
    localparam BIT_CNT = 96-1;

    reg [0:0] state = IDLE;
    reg mosi_bit;
    reg [BIT_CNT:0] data_out = 96'h9F_000000_0000_000000000000;
    //reg [BIT_CNT:0] data_in=   96'h12_345678_9abc_def123456789;
    reg [$clog2(BIT_CNT)-1:0] bit_count;

    assign sclk = (state == TRANSFER)?clk:0;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                ce <= 1; 
                state <= TRANSFER;
                bit_count <= BIT_CNT;  // Start from the MSB 
            end
            TRANSFER: begin
                ce <= 0;  
                mosi_bit <= data_out[bit_count];
                data_in[bit_count]<=miso;
                bit_count <= bit_count - 1;
                if (bit_count == 0) begin
                    state <= IDLE;
                end
            end
            endcase
    end


    always @(negedge clk) begin
        mosi <= data_out[bit_count];
    end

endmodule

// Stream bits to UART
module RegisterToUART#(parameter width=96)(
  input clk,          
  input [width-1:0] data,  
  output reg [7:0] tx_data,
  input uart_ready
);

    reg [width-1:0] data_latch;
    reg [$clog2(width/4)-1:0] cnt = 0;
    reg old_det;
    wire [3:0] nibble = data_latch[(width-1)-:4];
    
    always @(posedge clk) begin

        if(uart_ready) begin   
            if(cnt == (width/4)) begin
                data_latch <= data;
                cnt <= 0;
                tx_data <= 10;  // newline
            end else begin
                cnt <= cnt+1;
                data_latch <= data_latch<<4;
                tx_data <= (nibble<10)?nibble+"0":nibble+"A"-10;
            end
        end
    end
endmodule


module PLL(
    input clkin,
    output clkout
);
`ifdef BENCH
    assign clkout = clkin;
`else
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
`endif        
endmodule


// https://github.com/olofk/corescore/, Apache-2.0 license
module corescore_emitter_uart #(parameter clk_divider=12)(
   input wire 	    i_clk,
   input wire [7:0] i_data,
   output reg 	    o_ready,
   output wire 	    o_uart_tx
);

`ifdef BENCH
   localparam START_VALUE = 2;   
`else 
   localparam START_VALUE = clk_divider-2;   
`endif
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
