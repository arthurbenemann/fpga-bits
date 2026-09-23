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
    input      [2:0]  nbytes,       // data bytes to clock, 1..4
    output     [31:0] rdata,
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
    reg [2:0]  req_nbytes;

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
// by the first `nbytes` (1..4) bytes of wdata, MSB first, capturing the last 32 bits
// of MISO into rdata (meaningful for 4-byte reads).
//   write: cmd=0x02, read: cmd=0x03, read ID: cmd=0x9F (rdata = MFID,KGD,EID0,EID1)
// SCLK = clk/2, mode 0. MOSI changes on SCLK falling. MISO is sampled on the
// clk edge that drives SCLK low again, i.e. the bit the device launched one full
// SCLK period earlier: the MISO round trip gets 2 clk periods instead of 1.
module PSRAM_SPI (
    input             clk,
    input             start,
    input      [7:0]  cmd,
    input      [23:0] addr,
    input      [31:0] wdata,
    input      [2:0]  nbytes,
    output reg [31:0] rdata,
    output            busy,

    input             miso,
    output reg        mosi = 1'b0,
    output reg        ce   = 1'b1,
    output reg        sclk = 1'b0
);
    reg [63:0] shift_out;
    reg [31:0] shift_in;
    reg [6:0]  bit_count = 0;   // (32+8*nbytes-1) down to -1; bit 6 set means done
    reg        active = 1'b0;
    reg        phase  = 1'b0;   // 0: SCLK low / drive MOSI / sample MISO, 1: SCLK high

    wire done = bit_count[6];
    assign busy = active;

    // The sample taken on the very first SCLK-low edge is junk, but only the
    // last 32 samples are kept, so it falls out of shift_in.
    always @(posedge clk) begin
        if (!active) begin
            if (start) begin
                shift_out <= {cmd, addr, wdata};
                bit_count <= 7'd31 + {1'b0, nbytes, 3'b000};
                phase     <= 1'b0;
                active    <= 1'b1;
            end
        end else if (done) begin
            sclk   <= 1'b0;
            ce     <= 1'b1;
            rdata  <= {shift_in[30:0], miso};
            active <= 1'b0;
        end else if (!phase) begin
            ce        <= 1'b0;
            sclk      <= 1'b0;
            mosi      <= shift_out[63];
            shift_out <= shift_out << 1;
            shift_in  <= {shift_in[30:0], miso};
            phase     <= 1'b1;
        end else begin
            sclk      <= 1'b1;
            bit_count <= bit_count - 1;
            phase     <= 1'b0;
        end
    end
endmodule
