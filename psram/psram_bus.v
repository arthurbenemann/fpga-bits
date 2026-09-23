// PSRAM on the CPU memory bus.
//   Loads fetch the aligned 32-bit word (the CPU extracts bytes/halfwords itself).
//   Stores write exactly the bytes in wmask, in address order, so PSRAM holds the
//   same little-endian layout as the CPU sees. Stores are posted: accepted as soon
//   as the engine is idle, and the CPU moves on while the bytes are shifted out.
//   A load that arrives while a posted store is in flight waits for it, so reads
//   always observe earlier writes.
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

    wire        busy;
    wire [31:0] spi_rdata;
    reg         read_pending = 1'b0;
    reg         reading = 1'b0;

    // A store starts at its own byte address (addr[1:0]) and writes 1, 2 or 4
    // bytes: the only masks RISC-V produces.
    wire [2:0] count = &wmask ? 3'd4 : ^wmask ? 3'd1 : 3'd2;

    // Byte lanes in address order, lane 0 first. No shift to the first written
    // lane is needed: the core always carries sb/sh data in the low lanes too
    // (mem_wdata[7:0] = rs2[7:0], [15:8] = rs2[15:8] for aligned sh), so the
    // bytes to send always start at lane 0 whatever the address.
    wire [31:0] wdata_seq = {wdata[7:0], wdata[15:8], wdata[23:16], wdata[31:24]};

    wire start_write = sel && (|wmask) && !busy;
    wire start_read  = (read_pending || (sel && rstrb)) && !busy;

    always @(posedge clk) begin
        if (start_read) begin
            read_pending <= 1'b0;
            reading      <= 1'b1;
        end else begin
            if (sel && rstrb)
                read_pending <= 1'b1;       // a posted store is still in flight
            if (reading && !busy)
                reading <= 1'b0;
        end
    end

    assign rbusy = read_pending || (reading && busy);
    assign wbusy = sel && (|wmask) && busy;
    assign rdata = {spi_rdata[7:0], spi_rdata[15:8], spi_rdata[23:16], spi_rdata[31:24]};

    PSRAM_SPI_CDC spi (
        .clk(clk),
        .start(start_write || start_read),
        .cmd(start_write ? CMD_WRITE : CMD_READ),
        .addr({1'b0, addr[22:2], start_write ? addr[1:0] : 2'b00}),
        .wdata(wdata_seq),
        .nbytes(start_write ? count : 3'd4),
        .rdata(spi_rdata),
        .busy(busy),
        .clk_spi(clk_spi),
        .miso(miso),
        .mosi(mosi),
        .ce(ce),
        .sclk(sclk)
    );
endmodule
