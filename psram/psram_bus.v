// PSRAM on the CPU memory bus, behind a 64 KB direct-mapped write-through cache.
//   Lines are 16 bytes: data in two SPRAMs side by side (16K x 32 bits), tags in
//   EBR, one {valid, addr[22:16]} per line at index addr[15:4]. Configuration
//   clears the EBR, so every line starts invalid.
//   Tag and data are read every cycle at the current address. The core holds an
//   address for a cycle before it waits on it (FETCH_INSTR/LOAD before WAIT_*,
//   EXECUTE before STORE), so the tag compare is ready in time: hits cost nothing.
//   Load miss: one 16-byte burst read, the words go into the SPRAMs, the tag is
//   written, and the next read hits.
//   Stores are posted to PSRAM as before (the CPU moves on while the bytes are
//   shifted out) and update the cached copy on a hit; a store miss allocates
//   nothing. A miss that arrives while a store is in flight waits for it.
module PSRAM_BUS (
    input             clk,
    input             sel,         // address decodes to PSRAM
    input      [22:0] addr,        // byte address within the 8 MB
    input             rstrb,
    input      [31:0] wdata,
    input      [3:0]  wmask,
    output     [31:0] rdata,
    output            rbusy,
    output            wbusy,

    input             clk_spi,
    input             miso,
    output            mosi,
    output            ce,
    output            sclk
);
    localparam CMD_WRITE = 8'h02;
    localparam CMD_READ  = 8'h03;

    wire         busy;
    wire [127:0] line;             // burst read data, first byte on top
    reg          reading = 1'b0;   // a load is waiting for its data
    reg  [1:0]   fill = 2'd0;      // 0 idle, 1 bursting, 2 writing words, 3 re-reading
    reg  [1:0]   word = 2'd0;      // word being written during a fill

    wire [11:0] index = addr[15:4];
    wire [7:0]  tag   = {1'b1, addr[22:16]};

    reg  [7:0] tags [0:4095];
    reg  [7:0] tag_q;
    wire       hit = tag_q == tag;
    integer i;
    initial for (i = 0; i < 4096; i = i + 1) tags[i] = 8'b0;

    always @(posedge clk) begin
        if (fill == 2'd2 && &word) tags[index] <= tag;
        else                       tag_q <= tags[index];
    end

    // A store starts at its own byte address (addr[1:0]) and writes 1, 2 or 4
    // bytes: the only masks RISC-V produces. The core also carries sb/sh data
    // in the low lanes, so the bytes to send always start at lane 0.
    wire [2:0]  count = &wmask ? 3'd4 : ^wmask ? 3'd1 : 3'd2;
    wire [31:0] wdata_seq = {wdata[7:0], wdata[15:8], wdata[23:16], wdata[31:24]};

    wire start_write = sel && (|wmask) && !busy;
    wire start_read  = fill == 2'd0 && reading && !hit && !busy;

    always @(posedge clk) begin
        if (sel && rstrb) reading <= 1'b1;
        else if (!rbusy)  reading <= 1'b0;
        case (fill)
            2'd0: if (start_read) fill <= 2'd1;
            2'd1: if (!busy) fill <= 2'd2;
            2'd2: begin
                word <= word + 1;
                if (&word) fill <= 2'd3;
            end
            2'd3: fill <= 2'd0;
        endcase
    end

    assign rbusy = reading && (!hit || fill != 2'd0);
    assign wbusy = sel && (|wmask) && busy;

    // Cache data: fill words (byte 0 of the word is the first received) or store bytes.
    wire [31:0] seg       = line[127 - 32 * word -: 32];
    wire        filling   = fill == 2'd2;
    wire        data_we   = filling || (start_write && hit);
    wire [13:0] data_addr = {index, filling ? word : addr[3:2]};
    wire [31:0] data_in   = filling ? {seg[7:0], seg[15:8], seg[23:16], seg[31:24]} : wdata;
    wire [3:0]  data_mask = filling ? 4'b1111 : wmask;

    SB_SPRAM256KA data_lo (
        .ADDRESS(data_addr), .DATAIN(data_in[15:0]), .DATAOUT(rdata[15:0]),
        .MASKWREN({{2{data_mask[1]}}, {2{data_mask[0]}}}), .WREN(data_we),
        .CHIPSELECT(1'b1), .CLOCK(clk), .STANDBY(1'b0), .SLEEP(1'b0), .POWEROFF(1'b1)
    );
    SB_SPRAM256KA data_hi (
        .ADDRESS(data_addr), .DATAIN(data_in[31:16]), .DATAOUT(rdata[31:16]),
        .MASKWREN({{2{data_mask[3]}}, {2{data_mask[2]}}}), .WREN(data_we),
        .CHIPSELECT(1'b1), .CLOCK(clk), .STANDBY(1'b0), .SLEEP(1'b0), .POWEROFF(1'b1)
    );

    PSRAM_SPI_CDC spi (
        .clk(clk),
        .start(start_write || start_read),
        .cmd(start_write ? CMD_WRITE : CMD_READ),
        .addr({1'b0, addr[22:4], start_write ? addr[3:0] : 4'b0000}),
        .wdata(wdata_seq),
        .nbytes(start_write ? {2'b00, count} : 5'd16),
        .rdata(line),
        .busy(busy),
        .clk_spi(clk_spi),
        .miso(miso),
        .mosi(mosi),
        .ce(ce),
        .sclk(sclk)
    );
endmodule
