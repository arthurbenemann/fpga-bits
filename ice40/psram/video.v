// 320x200 8-bit framebuffer shown as 640x400 (2x2 pixels) in 640x480@60 DVI,
// through the 1BitSquared 12-bit DVI PMOD (TFP410) on PMOD 1A+1B.
//   Framebuffer: the two free SPRAMs side by side (16K x 32, 64 KB; bytes 64000
//   up are spare), plain read/write memory on the CPU clock. The CPU reads and
//   stores it like BRAM and always wins; in every other cycle the fetcher reads
//   a word for the line buffer.
//   Line buffer: 2 x 80 words, dual-clock EBR. The pixel side asks for fb line L
//   at the start of display row 38+2L (toggle req_t, first line flagged); the
//   CPU side fetches its 80 words into half L&1 within the next 2 rows (800 CPU
//   clocks) while rows 38+2L..39+2L show line L-1 from the other half.
//   Palette: 256 x 12-bit 0xRGB in EBR, written from the CPU clock; starts as
//   RGB 3-3-2. frames counts the frames the fetcher has finished reading.
//   Game mode (game_we bit0, latched at frame start into game_mode_cur): for
//   fb lines 0..167 the fetcher reads only 40 words/line (160 bytes, packed
//   1 byte/pixel) from view buffer 0 (bytes 0..26879) or 1 (26880..53759),
//   picked by front_req (bit1 of the same write, latched into front_cur,
//   readable back as game_front so the CPU knows when its flip landed); lines
//   168..199 (the status bar) always fetch 80 words/line from the normal
//   320-wide layout, i.e. the same bytes (53760..63999) either way. The pixel
//   side shows each of those 40 words' bytes 4 screen pixels wide instead of
//   2, for display rows within the same v range the fetcher treats as packed
//   (v<376, computed from v alone). game_mode/front_req only take effect at
//   the next frame's first line request, so they are quasi-static by the time
//   any consumer (either clock domain) reads them -- like req_first below,
//   read directly across the crossing with no synchronizer.
// Pixel clock 25.125 MHz (VESA: 25.175), 59.8 Hz frames, both sync pulses negative.
// The pins are registered in their IO cells; the clock pin is a DDR output
// inverted from clk_pix, so the TFP410 latches on its rising edge, mid data eye
// (as icebreaker-verilog-examples dvi-12bit does).
module VIDEO (
    input             clk,          // CPU clock
    input             sel,          // address decodes to the framebuffer
    input      [15:0] addr,
    input             rstrb,
    input      [31:0] wdata,
    input      [3:0]  wmask,
    output     [31:0] rdata,
    input             pal_we,       // palette[wdata[23:16]] <= wdata[11:0]
    input             game_we,      // game_mode <= wdata[0], front_req <= wdata[1]
    output            game_front,   // front_cur: which view buffer is on screen now
    output reg [31:0] frames = 0,

    input             clk_pix,
    output     [3:0]  dvi_r,
    output     [3:0]  dvi_g,
    output     [3:0]  dvi_b,
    output            dvi_clk,
    output            dvi_hs,
    output            dvi_vs,
    output            dvi_de
);
    // CPU side: framebuffer and fetcher
    wire        cpu = sel && (rstrb || |wmask);
    reg  [13:0] fetch_addr = 0;     // next fb word to fetch
    reg  [6:0]  n = 7'd80;          // words of the line fetched: 80 or 40, done
    reg  [7:0]  line = 0;           // fb line (0..199) currently being fetched
    reg         half = 0;
    reg  [2:0]  req_s = 0;          // req_t synchronized, and its previous value
    reg         lb_we = 0;
    reg  [7:0]  lb_wa;
    reg  [31:0] lbuf [0:255];
    wire [13:0] fb_addr = cpu ? addr[15:2] : fetch_addr;

    reg         game_mode = 0, front_req = 0;          // CPU requests, plain regs
    reg         game_mode_cur = 0, front_cur = 0;      // latched at frame start
    assign      game_front = front_cur;
    always @(posedge clk) if (game_we) begin
        game_mode <= wdata[0];
        front_req <= wdata[1];
    end

    wire [6:0] words_this_line = (game_mode_cur && line < 8'd168) ? 7'd40 : 7'd80;

    always @(posedge clk) begin
        req_s <= {req_s[1:0], req_t};
        lb_we <= 0;
        if (req_s[2] != req_s[1]) begin
            n <= 0;
            if (req_first) begin
                fetch_addr    <= (game_mode && front_req) ? 14'd6720 : 14'd0;
                half          <= 0;
                line          <= 0;
                game_mode_cur <= game_mode;
                front_cur     <= front_req;
            end else begin
                half <= !half;
                // Buffer 0's view rows (0..167) end at word 6720, short of the
                // status bar's fixed 13440; buffer 1's end right at 13440 (no
                // gap). Only the former needs an explicit jump.
                if (game_mode_cur && !front_cur && line == 8'd167)
                    fetch_addr <= 14'd13440;
                line <= line + 1;
            end
        end else if (n != words_this_line && !cpu) begin
            lb_we      <= 1;        // the word read this cycle is on rdata the next
            lb_wa      <= {half, n};
            n          <= n + 1;
            fetch_addr <= fetch_addr + 1;
            if (fetch_addr == 14'd15999) frames <= frames + 1;
        end
        if (lb_we) lbuf[lb_wa] <= rdata;
    end

    SB_SPRAM256KA fb_lo (
        .ADDRESS(fb_addr), .DATAIN(wdata[15:0]), .DATAOUT(rdata[15:0]),
        .MASKWREN({{2{wmask[1]}}, {2{wmask[0]}}}), .WREN(sel && |wmask),
        .CHIPSELECT(1'b1), .CLOCK(clk), .STANDBY(1'b0), .SLEEP(1'b0), .POWEROFF(1'b1)
    );
    SB_SPRAM256KA fb_hi (
        .ADDRESS(fb_addr), .DATAIN(wdata[31:16]), .DATAOUT(rdata[31:16]),
        .MASKWREN({{2{wmask[3]}}, {2{wmask[2]}}}), .WREN(sel && |wmask),
        .CHIPSELECT(1'b1), .CLOCK(clk), .STANDBY(1'b0), .SLEEP(1'b0), .POWEROFF(1'b1)
    );

    reg [11:0] pal [0:255];
    integer i;
    initial for (i = 0; i < 256; i = i + 1)
        pal[i] = {i[7:5], i[7], i[4:2], i[4], {2{i[1:0]}}};
    always @(posedge clk) if (pal_we) pal[wdata[23:16]] <= wdata[11:0];

    // Pixel side. H: 640 active, 16 front porch, 96 sync, 48 back porch.
    // V: 480, 10, 2, 33. The image is rows 40..439.
    reg [9:0] h = 10'd0, v = 10'd0;
    reg       req_t = 0, req_first = 0;
    always @(posedge clk_pix) begin
        h <= h == 10'd799 ? 10'd0 : h + 1;
        if (h == 10'd799) v <= v == 10'd524 ? 10'd0 : v + 1;
        if (h == 10'd0 && v >= 10'd38 && v <= 10'd436 && !v[0]) begin
            req_t     <= !req_t;
            req_first <= v == 10'd38;
        end
    end

    wire active = h < 10'd640 && v < 10'd480;
    wire image  = active && v >= 10'd40 && v < 10'd440;
    wire hs = !(h >= 10'd656 && h < 10'd752);
    wire vs = !(v >= 10'd490 && v < 10'd492);
    // fb line L = (v-40)>>1; L<168 <=> v<376. game_mode_cur crosses from clk
    // (see the module comment): safe here since it only changes right after
    // v==38's request, tens of clk_pix cycles before v==40 starts the image.
    wire game_row = game_mode_cur && v < 10'd376;

    // Pipeline: line buffer word, byte -> palette, then the IO registers.
    reg [31:0] word;
    reg [1:0]  sel_q;
    reg [11:0] rgb;
    reg [3:0]  sync_q, sync_qq;     // {image, hs, vs, active}, 2 clocks
    always @(posedge clk_pix) begin
        // Normal: 80 words/line, byte h[2:1] (2 screen pixels wide). Game: 40
        // words/line (only the low half of lbuf's 80-word half is filled), byte
        // h[3:2] (4 screen pixels wide).
        word      <= lbuf[{v[1], game_row ? {1'b0, h[9:4]} : h[9:3]}];
        sel_q     <= game_row ? h[3:2] : h[2:1];
        rgb       <= pal[word[8 * sel_q +: 8]];
        sync_q    <= {image, hs, vs, active};
        sync_qq   <= sync_q;
    end

    SB_IO #(.PIN_TYPE(6'b01_0000)) clk_io (     // DDR: low on the rising edge, high on the falling
        .PACKAGE_PIN(dvi_clk), .D_OUT_0(1'b0), .D_OUT_1(1'b1), .OUTPUT_CLK(clk_pix)
    );
    SB_IO #(.PIN_TYPE(6'b01_0100)) data_io [14:0] (    // registered outputs
        .PACKAGE_PIN({dvi_r, dvi_g, dvi_b, dvi_hs, dvi_vs, dvi_de}),
        .D_OUT_0({sync_qq[3] ? rgb : 12'h000, sync_qq[2:0]}),
        .OUTPUT_CLK(clk_pix)
    );
endmodule
