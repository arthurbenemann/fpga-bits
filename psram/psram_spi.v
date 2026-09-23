// Single-SPI PSRAM transaction engine: one 64-bit transfer of
// {cmd, addr[23:0], wdata[31:0]}, capturing the last 32 bits of MISO into rdata.
//   write: cmd=0x02, read: cmd=0x03, read ID: cmd=0x9F (rdata = MFID,KGD,EID0,EID1)
// SCLK = clk/2. MOSI changes on SCLK falling, MISO sampled at SCLK rising (mode 0).
module PSRAM_SPI (
    input             clk,
    input             start,
    input      [7:0]  cmd,
    input      [23:0] addr,
    input      [31:0] wdata,
    output reg [31:0] rdata,
    output            busy,

    input             miso,
    output reg        mosi = 1'b0,
    output reg        ce   = 1'b1,
    output reg        sclk = 1'b0
);
    reg [63:0] shift_out;
    reg [31:0] shift_in;
    reg [6:0]  bit_count = 0;
    reg        active = 1'b0;
    reg        phase  = 1'b0;   // 0: drive MOSI / SCLK low, 1: SCLK high / sample MISO

    assign busy = active;

    always @(posedge clk) begin
        if (!active) begin
            if (start) begin
                shift_out <= {cmd, addr, wdata};
                bit_count <= 64;
                phase     <= 1'b0;
                active    <= 1'b1;
            end
        end else if (bit_count == 0) begin
            sclk   <= 1'b0;
            ce     <= 1'b1;
            rdata  <= shift_in;
            active <= 1'b0;
        end else if (!phase) begin
            ce        <= 1'b0;
            sclk      <= 1'b0;
            mosi      <= shift_out[63];
            shift_out <= shift_out << 1;
            phase     <= 1'b1;
        end else begin
            sclk      <= 1'b1;
            shift_in  <= {shift_in[30:0], miso};
            bit_count <= bit_count - 1;
            phase     <= 1'b0;
        end
    end
endmodule
