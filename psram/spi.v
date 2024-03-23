module SPI(
    input           clk,
    // data
    input           strb,
    input  [7:0]    transmit,
    output reg [7:0]    received,
    output reg      valid,
    // SPI pins
    input           miso,
    output          sclk,
    output      mosi
);

    // SPI controller
    localparam IDLE = 0;
    localparam TRANSFER = 1;
    localparam BIT_CNT = 8;

    reg state = IDLE;
    reg [3:0] bitcount = 0;
    reg clkdiv2 =0;
    
    assign sclk = !clk && (state == TRANSFER);
    assign mosi = transmit[bitcount];

    always @(posedge clk) begin
        if(state == IDLE) begin
            valid = 0;
            if(strb) begin
                bitcount = 7;
                state = TRANSFER;
                received = miso;
            end else begin
                bitcount = 0;
            end
        end else begin
            if (bitcount!=0) begin
                bitcount = bitcount - 1;
                received = received<<1 | miso; 
            end else begin
                state = IDLE;
                valid = 1;
            end
        end
    end

endmodule