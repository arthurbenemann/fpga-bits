// PSRAM_SPI running on its own clock, with a toggle req/ack handshake to the
// CPU clock domain. Works at any clock ratio. cmd/addr/wdata are captured on
// start and held stable while the request is in flight; rdata is only written
// before ack toggles, so both cross as quasi-static values without synchronizers.
module PSRAM_SPI_CDC (
    input             clk,          // CPU domain
    input             start,
    input      [7:0]  cmd,
    input      [23:0] addr,
    input      [31:0] wdata,
    input      [4:0]  nbytes,       // data bytes to clock, 1..16
    output     [127:0] rdata,
    output reg        busy = 1'b0,

    input             clk_spi,      // SPI domain; SCLK = clk_spi/2
    input             miso,
    output            mosi,
    output            ce,
    output            sclk
);
    // CPU domain
    reg        req_t = 1'b0;
    reg [1:0]  ack_s = 2'b00;
    reg [7:0]  req_cmd;
    reg [23:0] req_addr;
    reg [31:0] req_wdata;
    reg [4:0]  req_nbytes;

    always @(posedge clk) begin
        ack_s <= {ack_s[0], ack_t};
        if (start && !busy) begin
            req_cmd   <= cmd;
            req_addr  <= addr;
            req_wdata <= wdata;
            req_nbytes <= nbytes;
            req_t     <= ~req_t;
            busy      <= 1'b1;
        end else if (busy && ack_s[1] == req_t) begin
            busy      <= 1'b0;
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

    PSRAM_SPI engine(
        .clk(clk_spi),
        .start(engine_start),
        .cmd(req_cmd),
        .addr(req_addr),
        .wdata(req_wdata),
        .nbytes(req_nbytes),
        .rdata(rdata),
        .busy(engine_busy),
        .miso(miso),
        .mosi(mosi),
        .ce(ce),
        .sclk(sclk)
    );
endmodule

// Single-SPI PSRAM transaction engine: one transfer of {cmd, addr[23:0]} followed
// by `nbytes` (1..16) data bytes: the first bytes of wdata (MSB first) on MOSI,
// with the last 128 bits of MISO kept in rdata, first byte on top. rdata holds
// still while the engine is idle.
//   write: cmd=0x02 (1..4 bytes), read: cmd=0x03 (16 bytes), read ID: cmd=0x9F
// SCLK = clk/2, mode 0. MOSI changes on SCLK falling. MISO is sampled on the
// clk edge that drives SCLK low again, i.e. the bit the device launched one full
// SCLK period earlier: the MISO round trip gets 2 clk periods instead of 1.
module PSRAM_SPI (
    input             clk,
    input             start,
    input      [7:0]  cmd,
    input      [23:0] addr,
    input      [31:0] wdata,
    input      [4:0]  nbytes,
    output     [127:0] rdata,
    output            busy,

    input             miso,
    output reg        mosi = 1'b0,
    output reg        ce   = 1'b1,
    output reg        sclk = 1'b0
);
    reg [63:0] shift_out;
    reg [127:0] shift_in;
    reg [8:0]  bit_count = 0;   // (32+8*nbytes-1) down to -1; bit 8 set means done
    reg        active = 1'b0;
    reg        phase  = 1'b0;   // 0: SCLK low / drive MOSI / sample MISO, 1: SCLK high

    wire done = bit_count[8];
    assign busy = active;
    assign rdata = shift_in;

    // The sample taken on the very first SCLK-low edge is junk, but only the
    // last 128 samples are kept, so it falls out of shift_in.
    always @(posedge clk) begin
        if (!active) begin
            // Loaded every idle cycle, not just on start: keeps start out of
            // this wide enable (the inputs are stable by the time start comes).
            shift_out <= {cmd, addr, wdata};
            bit_count <= 9'd31 + {1'b0, nbytes, 3'b000};
            phase     <= 1'b0;
            active    <= start;
        end else if (done) begin
            sclk   <= 1'b0;
            ce     <= 1'b1;
            shift_in <= {shift_in[126:0], miso};
            active <= 1'b0;
        end else if (!phase) begin
            ce        <= 1'b0;
            sclk      <= 1'b0;
            mosi      <= shift_out[63];
            shift_out <= shift_out << 1;
            shift_in  <= {shift_in[126:0], miso};
            phase     <= 1'b1;
        end else begin
            sclk      <= 1'b1;
            bit_count <= bit_count - 1;
            phase     <= 1'b0;
        end
    end
endmodule
