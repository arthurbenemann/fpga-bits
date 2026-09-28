// iverilog check of FLASH_SPI against a tiny W25Q model: 0xAB (wake, no-op
// here) then 0x03 + 24-bit address + streamed bytes = (address + i) & 0xFF,
// so the words read back are predictable and checkable.
`timescale 1ns/1ns

module tb;
    reg clk = 0;
    reg start = 0, pop = 0, stop = 0;
    reg [23:0] start_addr;
    wire [31:0] rdata;
    wire ready;
    wire sck, mosi, ssb, io2, io3;
    wire miso;

    always #10 clk = ~clk; // 50 MHz sim clock, doesn't need to match real timing

    FLASH_SPI dut (
        .clk(clk), .start(start), .start_addr(start_addr), .pop(pop), .stop(stop),
        .rdata(rdata), .ready(ready),
        .sck(sck), .mosi(mosi), .miso(miso), .ssb(ssb), .io2(io2), .io3(io3)
    );

    // Simple byte-shifting flash model: streams (addr+n) as consecutive bytes
    // after cmd(0x03)+addr, ignoring 0xAB (wake) transactions entirely (they
    // use their own short CS pulse and are never sampled for data).
    reg [7:0]  model_cmd;
    reg [23:0] model_addr;
    reg [4:0]  model_bits;
    reg        model_gotcmd, model_reading;
    reg [7:0]  model_byte;
    reg [31:0] model_n;
    reg [2:0]  out_bits;   // bit position within the byte being shifted out

    assign miso = model_byte[7];

    always @(posedge sck) begin
        if (!ssb) begin
            if (!model_gotcmd) begin
                model_cmd <= {model_cmd[6:0], mosi};
                model_bits <= model_bits + 1;
                if (model_bits == 5'd7) begin
                    model_gotcmd <= 1'b1;
                    model_bits <= 5'd0;
                end
            end else if (!model_reading) begin
                model_addr <= {model_addr[22:0], mosi};
                model_bits <= model_bits + 1;
                if (model_bits == 5'd23) begin
                    model_reading <= 1'b1;
                    out_bits <= 3'd0;
                end
            end
        end
    end

    always @(negedge sck) begin
        if (!ssb && model_reading) begin
            model_byte <= out_bits == 3'd0 ? model_addr[7:0] + model_n[7:0] : model_byte << 1;
            out_bits   <= out_bits + 1'b1;
            if (out_bits == 3'd7) model_n <= model_n + 1;
        end
    end

    always @(posedge ssb) begin
        model_gotcmd <= 1'b0;
        model_reading <= 1'b0;
        model_bits <= 5'd0;
        model_n <= 32'd0;
    end

    // @(posedge clk) alone resumes before this cycle's nonblocking updates
    // (e.g. have/word) have landed; a tick settles them before we look.
    task tick; begin @(posedge clk); #1; end endtask

    integer errors = 0;
    task expect_word(input [31:0] exp);
        begin
            while (!ready) tick;
            if (rdata !== exp) begin
                $display("FAIL: got %08x expected %08x", rdata, exp);
                errors = errors + 1;
            end else
                $display("ok: %08x", rdata);
            pop = 1; tick; pop = 0;
        end
    endtask

    initial begin
        start_addr = 24'h000010;
        tick;
        start = 1; tick; start = 0;
        // bytes streamed are addr+0, addr+1, addr+2, addr+3, ... so the first
        // word (little-endian) is {addr+3,addr+2,addr+1,addr+0}
        expect_word({8'h13, 8'h12, 8'h11, 8'h10});
        expect_word({8'h17, 8'h16, 8'h15, 8'h14});
        stop = 1; tick; stop = 0;

        // restart at a new address
        start_addr = 24'h000100;
        tick;
        start = 1; tick; start = 0;
        expect_word({8'h03, 8'h02, 8'h01, 8'h00});

        if (errors == 0) $display("PASS");
        else $display("FAILED: %0d errors", errors);
        $finish;
    end

    initial begin
        #200000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
