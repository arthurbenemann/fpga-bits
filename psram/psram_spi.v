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

    input             clk_spi,      // SPI domain; SCLK = clk_spi (DDR, see PSRAM_QPI)
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
// SCLK = clk (DDR output, mode 0): falls at clk's posedge, rises at the
// following negedge, so one SCLK period is one clk period (was two: clk/2) --
// one nibble per clk instead of one per two clk, halving burst time. `armed`
// holds CE low for one full clk before the first edge, well over tCSP (2.5 ns
// even at clk = 63 MHz). A new nibble is driven right after each falling edge
// (a full clk cycle -- most of a low+high SCLK period -- of setup before the
// device samples it at the next rising edge), and the device's reply to that
// same falling edge is captured here, once per clk, at the *next* falling
// edge: budget at clk = 63 MHz (15.9 ns/cycle) is tACLK max 6 ns plus
// round-trip PCB delay, comfortably inside one cycle -- the ESP-PSRAM64H is
// rated for this same same-period sampling up to 133/144 MHz (the 84 MHz limit
// only applies to bursts crossing a 1K page, which ours can't: lines are 16 B
// and page-aligned). SIO0-2 idle released (pulled up), SIO3 idle driven high
// (it doubles as the microSD DAT3/CS).
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
    output            sclk
);
    reg [63:0]  shift_out;
    reg [127:0] shift_in;
    reg [3:0]   sio_out = 4'hF;
    reg         sio_oe  = 1'b0;
    reg  [1:0]  ce_q    = 2'b11;
    reg [5:0]   left;           // nibbles left to send, this one included
    reg [3:0]   hdr;            // nibbles sent, saturating at 8: cmd+addr done
    reg         armed  = 1'b0;  // CE just went low; SCLK stays low one more clk
    reg         active = 1'b0;  // transferring: SCLK toggles once per clk

    wire [3:0]  sio_in;
    wire        lastnibble = left == 6'd0;
    wire [3:0]  hdr_next   = hdr + !hdr[3];
    assign busy  = armed || active;
    assign rdata = shift_in;

    SB_IO #(.PIN_TYPE(6'b01_0000)) sclk_io (   // DDR: low on clk's rising edge,
        .PACKAGE_PIN(sclk), .D_OUT_0(1'b0), .D_OUT_1(active), .OUTPUT_CLK(clk)
    );                                          // high on clk's falling edge

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
        if (!armed && !active) begin
            // Loaded every idle cycle, not just on start: keeps start out of
            // this wide enable (the inputs are stable by the time start comes).
            shift_out <= {cmd, addr, wdata};
            left      <= last[5:0];
            hdr       <= 4'd0;
            armed     <= start;
            if (start) ce <= 1'b0;
        end else if (armed) begin
            armed     <= 1'b0;
            active    <= 1'b1;
            sio_oe    <= 1'b1;           // nibble0 (cmd) is always driven
            sio_out   <= shift_out[63:60];
            shift_out <= shift_out << 4;
        end else begin
            // sio_oe here gates the *next* nibble, so it must look at hdr as it
            // will read once this nibble is counted (hdr_next), not as it reads
            // now -- otherwise SIO stays driven one nibble into the wait phase.
            sio_oe    <= lastnibble ? 1'b0 : (!rd || !hdr_next[3]);
            sio_out   <= lastnibble ? 4'hF : shift_out[63:60];
            shift_out <= shift_out << 4;
            shift_in  <= {shift_in[123:0], sio_in};
            hdr       <= hdr_next;
            left      <= left - 1'b1;
            ce        <= lastnibble;
            active    <= !lastnibble;
        end
    end
endmodule
