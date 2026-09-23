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


    reg [63:0] snapshot;
    always @(posedge clk)
        if (rvalid) snapshot <= spi_data;

    RegisterToUART #(.width(64)) r2u(.clk(clk),.data(snapshot),
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

    SPI #(.width(64)) psram(
        .clk(clk),
        .miso(RAM_SO),
        .mosi(RAM_SI),
        .ce(RAM_CE_B),
        .sclk(RAM_CLK),
        .rdata(spi_data),
        .rvalid(rvalid)
    );
    wire [63:0] spi_data;
    wire rvalid;
endmodule

// Writes WDATA to ADDR once, then repeatedly re-reads ADDR forever.
// rdata always reflects the most recent transaction: garbage (MISO
// undriven) right after the one-time write, real read data from then on.
module SPI #(
    parameter width = 64,
    parameter [23:0] ADDR  = 24'h000010,
    parameter [31:0] WDATA = 32'h12345678
)(
    input  clk,
    input  miso,
    output reg mosi,
    output reg ce,
    output reg sclk,
    output reg [width-1:0] rdata,
    output reg rvalid
);

    localparam CMD_WRITE = 8'h02;
    localparam CMD_READ  = 8'h03;

    // IDLE holds CE# high for 2 clk cycles (40 ns at 50 MHz); tCPH min is 18 ns.

    // SPI controller
    localparam IDLE = 0;
    localparam TRANSFER = 1;
    localparam BIT_CNT = width-1;

    reg [0:0] state = IDLE;
    reg did_write = 0;
    reg [width-1:0] data_out;
    reg [$clog2(BIT_CNT)-1:0] bit_count;
    reg clkdiv2 =0;


    always @(posedge clk) begin
        clkdiv2 <= !clkdiv2;
        case (state)
            IDLE: begin
                ce <= 1;
                sclk <=0;
                rvalid <=0;
                if (clkdiv2) begin  // rising
                    data_out <= did_write ? {CMD_READ, ADDR, 32'h0} : {CMD_WRITE, ADDR, WDATA};
                    bit_count <= BIT_CNT;
                    state <= TRANSFER;
                end
            end
            TRANSFER: begin
                ce <= 0;
                sclk <= clkdiv2;
                if (clkdiv2) begin  // rising
                    rdata <= {rdata[width-2:0], miso};
                    bit_count <= bit_count - 1;
                    if (bit_count == 0) begin
                        state <= IDLE;
                        rvalid <=1;
                        did_write <= 1;
                    end
                end else begin      // falling
                    mosi <= data_out[width-1];
                    data_out <= data_out << 1;
                end
            end
            endcase
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
    reg [$clog2(width/4+1)-1:0] cnt = 0;
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
