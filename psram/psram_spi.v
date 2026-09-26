// PSRAM_QPI running on its own clock, with a toggle req/ack handshake to the
// CPU clock domain. Works at any clock ratio. The request fields are captured
// on start and held stable while the request is in flight; rdata is only written
// before ack toggles, so both cross as quasi-static values without synchronizers.
module PSRAM_QPI_CDC (
    input             clk,          // CPU domain
    input             start,
    input      [7:0]  cmd,
    input      [23:0] addr,
    input      [31:0] wdata,
    input      [5:0]  last,         // SCLK cycles in the transfer, minus 1
    input             rd,           // release SIO after cmd+addr
    output     [127:0] rdata,
    output reg        busy = 1'b0,

    input             clk_spi,      // SPI domain; SCLK = clk_spi/2
    inout      [3:0]  sio,
    output            ce,
    output            sclk
);
    // CPU domain
    reg        req_t = 1'b0;
    reg [1:0]  ack_s = 2'b00;
    reg [7:0]  req_cmd;
    reg [23:0] req_addr;
    reg [31:0] req_wdata;
    reg [5:0]  req_last;
    reg        req_rd;

    always @(posedge clk) begin
        ack_s <= {ack_s[0], ack_t};
        if (start && !busy) begin
            req_cmd    <= cmd;
            req_addr   <= addr;
            req_wdata  <= wdata;
            req_last   <= last;
            req_rd     <= rd;
            req_t      <= ~req_t;
            busy       <= 1'b1;
        end else if (busy && ack_s[1] == req_t) begin
            busy       <= 1'b0;
        end
    end

    // SPI domain
    reg [1:0] req_s = 2'b00;
    reg       req_seen = 1'b0;
    reg       ack_t = 1'b0;
    wire      engine_busy;
    wire      engine_start = (req_s[1] != req_seen) && !engine_busy;

    always @(posedge clk_spi) begin
        req_s <= {req_s[0], req_t};
        if (engine_start)
            req_seen <= req_s[1];
        else if (!engine_busy)
            ack_t <= req_seen;
    end

    PSRAM_QPI engine(
        .clk(clk_spi),
        .start(engine_start),
        .cmd(req_cmd),
        .addr(req_addr),
        .wdata(req_wdata),
        .last(req_last),
        .rd(req_rd),
        .rdata(rdata),
        .busy(engine_busy),
        .sio(sio),
        .ce(ce),
        .sclk(sclk)
    );
endmodule

// QPI PSRAM transaction engine: `last`+1 SCLK cycles, a nibble per cycle on
// SIO[3:0]. The first 16 nibbles driven are {cmd, addr[23:0], wdata}, MSB first.
// With rd, SIO is released after cmd+addr (8 nibbles) and the last 32 nibbles
// read are kept in rdata, first byte on top. rdata holds still while idle.
//   quad write: cmd=0x38, 8+2*bytes steps     quad read: cmd=0xEB, rd, 8+6+32 steps
// A single-SPI command goes out as 8 nibbles with the bits on SIO0 (see PSRAM_BUS).
// SCLK = clk/2, mode 0. SIO changes on SCLK falling. SIO is sampled on the clk
// edge that drives SCLK low again, i.e. the nibble the device launched one full
// SCLK period earlier: the round trip gets 2 clk periods instead of 1.
// Idle: SIO0-2 released (pulled up), SIO3 driven high since it is also the
// microSD DAT3/CS; from two clks after CE rises, once the PSRAM has let go.
module PSRAM_QPI (
    input             clk,
    input             start,
    input      [7:0]  cmd,
    input      [23:0] addr,
    input      [31:0] wdata,
    input      [5:0]  last,
    input             rd,
    output     [127:0] rdata,
    output            busy,

    inout      [3:0]  sio,
    output reg        ce   = 1'b1,
    output reg        sclk = 1'b0
);
    reg [63:0]  shift_out;
    reg [127:0] shift_in;
    reg [3:0]   sio_out = 4'hF;
    reg         sio_oe  = 1'b0;
    reg  [1:0]  ce_q    = 2'b11;
    reg [6:0]   left;           // steps left - 1, down to -1; bit 6 set means done
    reg [3:0]   hdr;            // steps done, saturating at 8: cmd+addr sent
    reg         active = 1'b0;
    reg         phase  = 1'b0;   // 0: SCLK low / drive / sample, 1: SCLK high
    wire [3:0]  sio_in;

    wire done = left[6];
    assign busy = active;
    assign rdata = shift_in;

    SB_IO #(.PIN_TYPE(6'b1010_01), .PULLUP(1'b1)) io [3:0] (
        .PACKAGE_PIN(sio),
        .OUTPUT_ENABLE({sio_oe | (ce & ce_q[1]), {3{sio_oe}}}),
        .D_OUT_0(sio_out),
        .D_IN_0(sio_in)
    );

    // The samples taken during cmd+addr+wait are junk, but only the last 32
    // are kept, so they fall out of shift_in.
    always @(posedge clk) begin
        ce_q <= {ce_q[0], ce};
        if (!active) begin
            // Loaded every idle cycle, not just on start: keeps start out of
            // this wide enable (the inputs are stable by the time start comes).
            shift_out <= {cmd, addr, wdata};
            left      <= {1'b0, last};
            hdr       <= 4'd0;
            phase     <= 1'b0;
            active    <= start;
        end else if (done) begin
            sclk     <= 1'b0;
            ce       <= 1'b1;
            sio_oe   <= 1'b0;
            sio_out  <= 4'hF;
            shift_in <= {shift_in[123:0], sio_in};
            active   <= 1'b0;
        end else if (!phase) begin
            ce        <= 1'b0;
            sclk      <= 1'b0;
            sio_oe    <= !rd || !hdr[3];
            sio_out   <= shift_out[63:60];
            shift_out <= shift_out << 4;
            shift_in  <= {shift_in[123:0], sio_in};
            phase     <= 1'b1;
        end else begin
            sclk      <= 1'b1;
            left      <= left - 1;
            hdr       <= hdr + !hdr[3];
            phase     <= 1'b0;
        end
    end
endmodule
