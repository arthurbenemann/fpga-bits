`timescale 1ns/1ps
`define BENCH
// Self-checking bench: existing SPI master vs behavioural ESP-PSRAM64H.
// Models board/IO delay so the MISO sampling margin is actually exercised.
module tb_spi;
    parameter real TCO      = 8.0;  // PSRAM clock-to-out
    parameter real T_OUT    = 5.0;  // FPGA clk->pin + trace, master -> device
    parameter real T_IN     = 3.0;  // device -> FPGA pin + pad delay
    parameter real CLKP     = 20.0; // 50 MHz core clock (matches the real PLL)

    reg clk = 0;
    always #(CLKP/2.0) clk = ~clk;

    wire mosi, ce, sclk;
    wire [95:0] rdata;
    wire rvalid;
    wire miso_fpga;

    // --- board delays -------------------------------------------------
    wire sclk_dev, mosi_dev, ce_dev;
    assign #(T_OUT) sclk_dev = sclk;
    assign #(T_OUT) mosi_dev = mosi;
    assign #(T_OUT) ce_dev   = ce;
    wire so_dev;
    assign #(T_IN)  miso_fpga = so_dev;

    SPI dut (.clk(clk), .miso(miso_fpga), .mosi(mosi), .ce(ce),
             .sclk(sclk), .rdata(rdata), .rvalid(rvalid));

    psram_model #(.TCO(TCO)) mem (
        .ce_n(ce_dev), .sclk(sclk_dev), .si(mosi_dev), .so(so_dev));

    // --- checker ------------------------------------------------------
    integer xfers = 0, pass = 0, fail = 0;
    reg [95:0] snap;
    always @(posedge clk) if (rvalid) begin
        snap  = rdata;
        xfers = xfers + 1;
        if (snap[63:48] === 16'h0D5D) pass = pass + 1;
        else begin
            fail = fail + 1;
            if (fail <= 3)
              $display("[%0t] MISMATCH #%0d: rdata[63:48]=%h (want 0D5D) full=%h",
                       $time, xfers, snap[63:48], snap);
        end
    end

    // --- measure SCLK period & CE# low time ---------------------------
    time t_rise_prev = 0, t_ce_lo = 0;
    real sclk_mhz;
    always @(posedge sclk) begin
        if (t_rise_prev != 0) sclk_mhz = 1000.0 / ($time - t_rise_prev);
        t_rise_prev = $time;
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_spi.vcd"); $dumpvars(0, tb_spi);
        end
        #200000;  // 200 us
        $display("--------------------------------------------------------");
        $display("TCO=%0.1fns T_OUT=%0.1f T_IN=%0.1f  core=%0.1fMHz sclk=%0.2fMHz",
                 TCO, T_OUT, T_IN, 1000.0/CLKP, sclk_mhz);
        $display("transfers=%0d  pass=%0d  fail=%0d", xfers, pass, fail);
        $display("tCEM violations=%0d  tCPH violations=%0d",
                 mem.n_tcem_viol, mem.n_tcph_viol);
        $display("--------------------------------------------------------");
        $finish;
    end
endmodule
