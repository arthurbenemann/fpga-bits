// Mode-0 SPI master, shift-register based, with a handshake and a
// selectable MISO sample point.
//   SAMPLE_LATE=0 : sample on the SCLK rising edge  (round-trip budget = 1 core clk)
//   SAMPLE_LATE=1 : sample on the SCLK falling edge (round-trip budget = 2 core clks)
// SCLK = clk/2.  CE# low time = WIDTH*2 core clks -- keep under tCEM (8 us).
module spi_master #(
    parameter integer WIDTH       = 96,
    parameter integer SAMPLE_LATE = 1,
    parameter integer CS_HIGH_CYC = 2      // tCPH guard, in core clks
)(
    input  wire             clk,
    input  wire             rstn,
    input  wire             start,
    input  wire [WIDTH-1:0] tx_data,
    output reg  [WIDTH-1:0] rx_data,
    output reg              done,
    output wire             busy,
    input  wire             miso,
    output reg              mosi,
    output reg              ce_n,
    output reg              sclk
);
    localparam integer HW = $clog2(2*WIDTH + 1);   // NOTE: +1, see review
    localparam IDLE = 2'd0, LEAD = 2'd1, SHIFT = 2'd2;

    reg [1:0]        state;
    reg [HW-1:0]     half;
    reg [WIDTH-1:0]  shreg;
    reg [2:0]        gap;

    assign busy = (state != IDLE) || (gap != 0);

    initial begin
        state = IDLE; ce_n = 1'b1; sclk = 1'b0; mosi = 1'b0;
        rx_data = {WIDTH{1'b0}}; done = 1'b0; half = 0; gap = 0;
        shreg = {WIDTH{1'b0}};
    end

    wire rising = ~half[0];    // this edge drives SCLK high
    wire last   = (half == 2*WIDTH - 1);

    always @(posedge clk) begin
        done <= 1'b0;
        if (!rstn) begin
            state <= IDLE; ce_n <= 1'b1; sclk <= 1'b0; gap <= 0; half <= 0;
        end else begin
            case (state)
            IDLE: begin
                sclk <= 1'b0;
                if (gap != 0) begin
                    gap  <= gap - 1'b1;
                    ce_n <= 1'b1;
                end else if (start) begin
                    shreg <= tx_data;
                    mosi  <= tx_data[WIDTH-1];  // first bit valid before CE# falls
                    ce_n  <= 1'b0;
                    half  <= 0;
                    state <= LEAD;
                end
            end
            LEAD: state <= SHIFT;               // tCSS: one full clk of CE# low, SCLK still low
            SHIFT: begin
                half <= half + 1'b1;
                if (rising) begin
                    sclk <= 1'b1;
                    if (SAMPLE_LATE == 0) rx_data <= {rx_data[WIDTH-2:0], miso};
                end else begin
                    sclk <= 1'b0;
                    if (SAMPLE_LATE != 0) rx_data <= {rx_data[WIDTH-2:0], miso};
                    shreg <= {shreg[WIDTH-2:0], 1'b0};
                    mosi  <= shreg[WIDTH-2];
                    if (last) begin
                        ce_n  <= 1'b1;
                        done  <= 1'b1;
                        gap   <= CS_HIGH_CYC[2:0];
                        state <= IDLE;
                    end
                end
            end
            default: state <= IDLE;
            endcase
        end
    end
endmodule
