// Streaming reader for the on-board SPI flash (W25Q128, 16 MB), plain single-
// SPI 0x03 reads (no QE bit, no dummy clocks needed). SCLK = clk/2. Wakes the
// chip (0xAB, release power-down) before every transfer -- harmless if it's
// already awake -- since the FPGA may leave it powered down after
// configuration. IO2/IO3 (WP#/HOLD#) are held high; only IO0 (MOSI) and IO1
// (MISO) are used.
//
// Software interface (ready-bit poll, like the Mandelbrot accelerator; see
// soc.v): a stalling read would need the pipelined core's mem_rbusy path,
// which this keeps out of -- a poll is a couple of extra instructions and
// can't get the CPU's stall timing wrong.
//   write ADDR   latch start_addr, (re)start a continuous read at that byte
//                address; drops any transfer in progress first
//   read  ADDR   bit 0: a word is ready on DATA
//   read  DATA   the ready word (little-endian, as stored); popping it lets
//                streaming continue automatically to the next word
//   write END    raise CS, go idle (write any value)
module FLASH_SPI (
    input         clk,
    input         start,
    input  [23:0] start_addr,
    input         pop,
    input         stop,
    output [31:0] rdata,
    output        ready,

    output        sck,
    output        mosi,
    input         miso,
    output        ssb,
    output        io2,
    output        io3
);
    assign io2 = 1'b1;
    assign io3 = 1'b1;

    localparam CMD_WAKE = 8'hAB;
    localparam CMD_READ = 8'h03;

    // Clock cycles (2 per SCK bit) to cover tRES1 (wake, <=3us) and tSHSL
    // (CS high time, ~50ns): 200 clk @ 25 MHz = ~8us, ample margin either way,
    // and negligible next to a multi-megabyte streamed transfer.
    localparam GAP_TICKS = 9'd200;

    localparam S_IDLE   = 3'd0,
               S_RAISE  = 3'd1,   // CS high pulse before (re)starting
               S_WAKE   = 3'd2,   // shifting out 0xAB
               S_GAP    = 3'd3,   // CS high, tRES1
               S_CMD    = 3'd4,   // shifting out 0x03 + 24-bit address
               S_STREAM = 3'd5;   // shifting in data bytes, 4 at a time

    reg  [2:0]  state = S_IDLE;
    reg         cs    = 1'b1;
    reg         half  = 1'b0;     // 0: about to raise SCK, 1: about to lower it
    reg  [39:0] out_sr;           // shift-out: cmd+addr, MSB first
    reg  [5:0]  bits_left;
    reg  [7:0]  in_sr;
    reg  [2:0]  bit_cnt;          // bits received into in_sr (wraps 7->0)
    reg  [1:0]  byte_cnt;         // bytes received into word (wraps 3->0)
    reg  [31:0] word;
    reg         have = 1'b0;
    reg  [8:0]  gap;
    reg  [23:0] addr_q;

    assign ssb   = cs;
    assign sck   = ~cs & half;
    assign mosi  = out_sr[39];
    assign rdata = word;
    assign ready = have;

    wire pop_eff = pop & have;    // guards against a spurious pop while !have

    always @(posedge clk) begin
        if (stop) begin
            state <= S_IDLE;
            cs    <= 1'b1;
            have  <= 1'b0;
        end else if (start) begin
            state  <= S_RAISE;
            cs     <= 1'b1;
            gap    <= GAP_TICKS;
            addr_q <= start_addr;
            have   <= 1'b0;
        end else case (state)
            S_RAISE: if (gap == 9'd0) begin
                state     <= S_WAKE;
                cs        <= 1'b0;
                half      <= 1'b0;
                out_sr    <= {CMD_WAKE, 32'b0};
                bits_left <= 6'd8;
            end else gap <= gap - 1'b1;

            S_WAKE: if (!half) begin
                half <= 1'b1;
            end else begin
                half      <= 1'b0;
                out_sr    <= out_sr << 1;
                bits_left <= bits_left - 1'b1;
                if (bits_left == 6'd1) begin
                    state <= S_GAP;
                    cs    <= 1'b1;
                    gap   <= GAP_TICKS;
                end
            end

            S_GAP: if (gap == 9'd0) begin
                state     <= S_CMD;
                cs        <= 1'b0;
                half      <= 1'b0;
                out_sr    <= {CMD_READ, addr_q, 8'b0};
                bits_left <= 6'd32;
            end else gap <= gap - 1'b1;

            S_CMD: if (!half) begin
                half <= 1'b1;
            end else begin
                half      <= 1'b0;
                out_sr    <= out_sr << 1;
                bits_left <= bits_left - 1'b1;
                if (bits_left == 6'd1) begin
                    state    <= S_STREAM;
                    byte_cnt <= 2'd0;
                    bit_cnt  <= 3'd0;
                end
            end

            S_STREAM: if (!(have && !pop_eff)) begin
                if (!half) begin
                    half <= 1'b1;
                end else begin
                    half    <= 1'b0;
                    in_sr   <= {in_sr[6:0], miso};
                    bit_cnt <= bit_cnt + 1'b1;
                    if (bit_cnt == 3'd7) begin
                        word <= {in_sr[6:0], miso, word[31:8]};
                        if (byte_cnt == 2'd3) have <= 1'b1;
                        byte_cnt <= byte_cnt + 1'b1;
                    end
                end
            end
        endcase
        if (pop_eff) have <= 1'b0;
    end
endmodule
