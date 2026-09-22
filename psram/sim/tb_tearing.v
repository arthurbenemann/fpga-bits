`timescale 1ns/1ps
module tb_tearing;
  reg CLK=0; always #10 CLK=~CLK;
  wire [4:0] LEDS; wire TXD,RAM_SI,RAM_CE_B,RAM_CLK; wire RAM_SO;
  wire sd,md,cd,so;
  assign #5 sd=RAM_CLK; assign #5 md=RAM_SI; assign #5 cd=RAM_CE_B; assign #3 RAM_SO=so;
  SOC soc(.CLK(CLK),.RESET(1'b1),.LEDS(LEDS),.TXD(TXD),
          .RAM_SI(RAM_SI),.RAM_CE_B(RAM_CE_B),.RAM_CLK(RAM_CLK),.RAM_SO(RAM_SO));
  psram_model mem(.ce_n(cd),.sclk(sd),.si(md),.so(so));
  integer latches=0,torn=0,ce_short=0;
  always @(posedge CLK)
    if (soc.r2u.uart_ready && soc.r2u.cnt==24) begin
      latches=latches+1;
      if (soc.psram.state==1'b1) torn=torn+1;
    end
  time tr; initial tr=0;
  always @(posedge RAM_CE_B) tr=$time;
  always @(negedge RAM_CE_B) if(tr!=0 && ($time-tr)<18) ce_short=ce_short+1;
  // capture the printed line
  reg [8*64:1] line; integer p=0;
  always @(posedge CLK) if (soc.r2u.uart_ready) begin
     if (soc.r2u.tx_data==10) begin if(p>0) $display("   UART line: %0s", line); p=0; line=0; end
     else begin line = {line[8*63:1], soc.r2u.tx_data}; p=p+1; end
  end
  initial begin #4000000;
    $display(">> latches=%0d  torn(mid-transfer)=%0d  => %0d%% of printed values are TORN",
             latches,torn,(latches>0)?(100*torn)/latches:0);
    $display(">> CE# high < tCPH(18ns): %0d   tCEM violations: %0d", ce_short, mem.n_tcem_viol);
    $finish; end
endmodule
