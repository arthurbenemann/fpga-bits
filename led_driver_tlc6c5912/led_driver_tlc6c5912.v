

module ShiftReg( 
    //  CLR_B should always be 1, G_B controlled externally
    input clk,   // clk max freq of 10MHz
    input [11:0] rgb_x4,    // rgb data 
    output SR_LATCH,SR_Q,SR_CK
);

    reg [3:0] cnt;
    assign SR_CK = clk;
    assign SR_Q = (rgb_x4>>cnt);
    
    always @(negedge clk) begin
        if(cnt==0) begin
            cnt<=11;
            SR_LATCH<=1;
        end else begin
            cnt<=cnt-1;
            SR_LATCH<=0;
        end
    end

endmodule


module SOC (
        input  CLK,        
        input  RESET,      
        output P1A1,P1A2,P1A3
    );    
    
    reg [11:0] rgb_x4 = 'b111000101010;

    ShiftReg sr1(.clk(CLK),.rgb_x4(rgb_x4),.SR_LATCH(P1A3),.SR_Q(P1A2),.SR_CK(P1A1));    
endmodule


module multi_pwm_controller (
  input clk,
  input [11:0] duty_cycle [7:0],
  output [11:0] pwm_output
);

  reg [7:0] counter [11:0];
  reg [11:0] pwm_output_reg;

  always @(posedge clk) begin
    for (int i = 0; i < 12; i = i + 1) begin
      if (counter[i] == duty_cycle[i]) begin
        counter[i] <= 8'b00000000;
        pwm_output_reg[i] <= 1'b1;
      end else begin
        counter[i] <= counter[i] + 1;
        pwm_output_reg[i] <= 1'b0;
      end
    end
  end

  assign pwm_output = pwm_output_reg;

endmodule