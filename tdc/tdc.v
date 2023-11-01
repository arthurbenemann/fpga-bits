/*
    TDC test

        With WIDTH 100, and FREQ as set: (input is clk)

    025MHz: .00000000000000000000000000000000000000000000000000000000............................................ ?
    050MHz: .000000000000000000.0.................................................0000000000000000000000000000... 0.25ns
    075MHz: 000000................................000000000000000000000...0................................0...00 0.23ns
    100MHz: 00...........................000000000................................00000000....................... 0.28ns


    cat5 cable progations speed ~=200mm/ns

    310mm:  ................000000.0000000000000000000000000000..................................................
    500mm: .............000000000000000000000000000000.0...00..................................................0
    977mm: .000000000000000000000000000000000.........................................................0000000000

    Measured with wavegen
    -30ns   ..............................................................................................................................................................................................................................................000
    -20ns   ........................................................................................................................................................................0000000000000000000000000000000000000000000000000000000000000000000000000
    -10ns   ...........................................................................................................00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    0ns     .......000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

 

*/

`define FREQ 25
`define WIDTH 240

module TDC(
    input clk,tdc_in,
    output [`WIDTH:0] data
);
	wire [`WIDTH+1:0] carrydata;
    wire [`WIDTH+1:0] lutdata;
	assign carrydata[0] = tdc_in;
    
	genvar i;
	generate
	for (i=0; i <= `WIDTH; i=i+1) begin: generate_sample           
        (*keep*) SB_CARRY tdc_carry (
            .I0(0), .I1(1),
            .CI(carrydata[i]),
            .CO(carrydata[i+1])
        );        

        (* keep *) SB_LUT4 #(.LUT_INIT(16'b1111_1111_0000_0000)) tdc_lut (
            .I0(0),.I1(0),.I2(1),.I3(carrydata[i]),
            .O(lutdata[i])
        );
        (*keep*) SB_DFF tdc_dff(  
            .Q(data[i]),.C(clk),
            .D(lutdata[i])
        );
	end
	endgenerate
endmodule

module SOC (
        input  CLK,        
        input  RESET,      
        output [4:0] LEDS, 
        output TXD,
        input P1A4,
        input P1A3
    );    
    assign LEDS = 1;
    assign tdc_clk = P1A4;
    assign tdc_in = P1A3;
    

    PLL pll1(.clkin(CLK),.clkout(clk));
    wire clk;
    
	
	TDC tdc1(.clk(tdc_clk), .tdc_in(tdc_in), .data(data));	
    wire [`WIDTH:0] data;
    wire tdc_in,tdc_clk;

    RegisterToUART r2u(.clk(clk),.data(data),.tx_data(tx_data),.uart_ready(uart_ready));
    wire [7:0] tx_data;
    wire uart_ready;
    
    corescore_emitter_uart #(
        .clk_divider(`FREQ)     // Fin=50Mhz, baud =50Mhz/50 = 1Mbaud
    ) UART(
        .i_clk(clk),
        .i_data(tx_data),
        .o_ready(uart_ready),
        .o_uart_tx(TXD)			       
    );
    
endmodule


// Stream bits to UART
module RegisterToUART(
  input clk,          
  input [`WIDTH:0] data,  
  output reg [7:0] tx_data,
  input uart_ready
);
    reg [`WIDTH:0] data_latch;
    reg [7:0] cnt=0;
    
    always @(posedge clk) begin
        if(uart_ready) begin   
            if(cnt ==`WIDTH+1) begin
                cnt <= 0;
                data_latch <= data;
                tx_data <= 10;
            end else begin
                cnt <= cnt+1;
                data_latch <= data_latch>>1;
                tx_data <= data_latch[0]? 46 : 48;
            end
        end
    end
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
    
    generate
        case(`FREQ)
        25: begin
            defparam pll.DIVR = 4'b0000;
            defparam pll.DIVF = 7'b1000010;
            defparam pll.DIVQ = 3'b101;
            defparam pll.FILTER_RANGE = 3'b001;
            end
        50: begin
            defparam pll.DIVR = 4'b0000;
            defparam pll.DIVF = 7'b1000010;
            defparam pll.DIVQ = 3'b100;
            defparam pll.FILTER_RANGE = 3'b001;
            end
        75: begin
            defparam pll.DIVR = 4'b0000;
            defparam pll.DIVF = 7'b0110001;
            defparam pll.DIVQ = 3'b011;
            defparam pll.FILTER_RANGE = 3'b001;
            end
        100: begin
            defparam pll.DIVR = 4'b0000;
            defparam pll.DIVF = 7'b1000010;
            defparam pll.DIVQ = 3'b011;
            defparam pll.FILTER_RANGE = 3'b001;
            end        
        default: UNKNOWN_FREQUENCY unknown();
        endcase
    endgenerate 
        
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
