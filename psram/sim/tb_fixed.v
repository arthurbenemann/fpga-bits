`timescale 1ns/1ps
module tb_fixed;
    parameter real    TCO      = 8.0;
    parameter real    T_OUT    = 5.0;
    parameter real    T_IN     = 3.0;
    parameter real    CLKP     = 20.0;
    parameter integer LATE     = 1;

    reg clk = 0; always #(CLKP/2.0) clk = ~clk;
    reg rstn = 0; initial #(CLKP*5) rstn = 1;

    wire mosi, ce_n, sclk, busy, done, miso_fpga;
    wire [95:0] rx;
    wire sclk_dev, mosi_dev, ce_dev, so_dev;
    assign #(T_OUT) sclk_dev  = sclk;
    assign #(T_OUT) mosi_dev  = mosi;
    assign #(T_OUT) ce_dev    = ce_n;
    assign #(T_IN)  miso_fpga = so_dev;

    spi_master #(.WIDTH(96), .SAMPLE_LATE(LATE)) dut (
        .clk(clk), .rstn(rstn), .start(rstn & ~busy), .tx_data(96'h9F_000000_0000_000000000000),
        .rx_data(rx), .done(done), .busy(busy),
        .miso(miso_fpga), .mosi(mosi), .ce_n(ce_n), .sclk(sclk));

    psram_model #(.TCO(TCO)) mem (.ce_n(ce_dev), .sclk(sclk_dev), .si(mosi_dev), .so(so_dev));

    integer xfers=0, pass=0, fail=0;
    always @(posedge clk) if (done) begin
        xfers = xfers + 1;
        if (rx[63:48] === 16'h0D5D) pass = pass + 1;
        else begin
            fail = fail + 1;
            if (fail <= 2) $display("[%0t] MISMATCH: rx[63:48]=%h full=%h", $time, rx[63:48], rx);
        end
    end

    time tp=0; real sclk_mhz=0;
    always @(posedge sclk) begin if (tp!=0) sclk_mhz = 1000.0/($time-tp); tp=$time; end

    initial begin
        #200000;
        $display("LATE=%0d TCO=%0.1f  sclk=%0.2fMHz  xfers=%0d pass=%0d fail=%0d  tCEM_viol=%0d tCPH_viol=%0d",
                 LATE, TCO, sclk_mhz, xfers, pass, fail, mem.n_tcem_viol, mem.n_tcph_viol);
        $finish;
    end
endmodule
