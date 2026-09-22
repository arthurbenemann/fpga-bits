`timescale 1ns/1ps
module tb_tcem;
    parameter integer W = 256;   // 256-bit burst = 32 bytes @ 25MHz SCLK
    reg clk=0; always #10 clk=~clk;
    reg rstn=0; initial #100 rstn=1;
    wire mosi,ce_n,sclk,busy,done; wire [W-1:0] rx;
    wire sd,md,cd,so;
    assign #5 sd=sclk; assign #5 md=mosi; assign #5 cd=ce_n; wire mi; assign #3 mi=so;
    spi_master #(.WIDTH(W)) dut(.clk(clk),.rstn(rstn),.start(rstn&~busy),.tx_data({8'h9F,{(W-8){1'b0}}}),
       .rx_data(rx),.done(done),.busy(busy),.miso(mi),.mosi(mosi),.ce_n(ce_n),.sclk(sclk));
    psram_model mem(.ce_n(cd),.sclk(sd),.si(md),.so(so));
    time f,r; real lowus;
    always @(posedge ce_n) begin r=$time; lowus=(r-f)/1000.0; end
    always @(negedge ce_n) f=$time;
    initial begin #60000;
      $display(">> WIDTH=%0d bits: CE# low = %0.2f us (tCEM max 8.00 us) -- violations=%0d",
               W, lowus, mem.n_tcem_viol); $finish; end
endmodule
