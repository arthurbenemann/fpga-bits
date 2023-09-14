`include "clockworks.v"


module Memory (
    input               clk,
    input      [31:0]   mem_addr,  // address to be read
    output reg [31:0]   mem_rdata, // data read from memory
    input   	        mem_rstrb  // goes high when processor wants to read
);
    reg [31:0] MEM [0:255];     // RAM

   always @(posedge clk) begin
      if(mem_rstrb) begin
         mem_rdata <= MEM[mem_addr[31:2]];
      end
   end


    `ifdef BENCH
        localparam slow_bit=12;
    `else
        localparam slow_bit=12+4;
    `endif


    // debug
    `include "riscv_assembly.v"
    integer _mul  = 28;
    integer _mul_loop = 40;
    integer _mul_exit = 56;
   
    initial begin
        LI(a0,4637);   // Multiplication factor1
        LI(a1,251);   // Multiplication factor2
//        NOP();       // remove NOP as needed to keep label position
        
        CALL(LabelRef(_mul));
        MV(a0,a0);  // a0 is LEDs
        EBREAK(); 

    Label(_mul);   
        MV(t0,a0);
        MV(t1,a1);
        LI(a0,0);
    Label(_mul_loop);   
        BEQZ(t0,LabelRef(_mul_exit));
        ADD(a0,a0,t1);
        ADDI(t0,t0,-1);
        J(LabelRef(_mul_loop));
    Label(_mul_exit);   
        RET();

        endASM();
    
    end

endmodule

module Processor (
    input 	      clk,
    input 	      resetn,
    output     [31:0] mem_addr, 
    input      [31:0] mem_rdata, 
    output 	      mem_rstrb,
    output reg [31:0] x10_s		  
);


    // CPU state machine
    localparam FETCH_INSTR = 0;
    localparam WAIT_INSTR  = 1;
    localparam FETCH_REGS  = 2;
    localparam EXECUTE     = 3;

    reg [1:0] state = FETCH_INSTR;
    
    assign mem_addr = PC;
    assign mem_rstrb = (state == FETCH_INSTR);

    always @(posedge clk) begin
        if(!resetn) begin
	        PC <= 0;
	        state <= FETCH_INSTR;
        end else begin
            if(writeBackEn && rdId != 0) begin
                RegisterBank[rdId] <= writeBackData;
                
                // For displaying what happens.
                if(rdId == 10) begin
                    x10_s <= writeBackData;
                end
                `ifdef BENCH	 
                        $display("x%0d <= %b : d%d",rdId,writeBackData,writeBackData);
                `endif	
	        end

	        case(state)
	        FETCH_INSTR: begin
	            state <= WAIT_INSTR;
	        end
	        WAIT_INSTR: begin
	            instr <= mem_rdata;
	            state <= FETCH_REGS;
	        end
	        FETCH_REGS: begin
	            rs1 <= RegisterBank[rs1Id];
	            rs2 <= RegisterBank[rs2Id];
	            state <= EXECUTE;
	        end
	        EXECUTE: begin
                if(!isSYSTEM) begin
	                PC <= nextPC;
                end
	            state <= FETCH_INSTR;	      
                `ifdef BENCH      
                    if(isSYSTEM) $finish();
                `endif   
	        end
	        endcase
            
        end
    end 


    // Registers
    reg [31:0] PC =0;              // program counter
    reg [31:0] instr;           // current instruction

    reg [31:0] RegisterBank [0:31];
    reg [31:0] rs1;
    reg [31:0] rs2;



   // Address computation
   // An adder used to compute branch address, JAL address and AUIPC.
   // branch->PC+Bimm    AUIPC->PC+Uimm    JAL->PC+Jimm
   // Equivalent to PCplusImm = PC + (isJAL ? Jimm : isAUIPC ? Uimm : Bimm)
    wire [31:0] PCplusImm = PC + ( isJAL ? Jimm[31:0] :
	  			                 isAUIPC ? Uimm[31:0] :
				                           Bimm[31:0] );
    wire [31:0] PCplus4 = PC+4;
    
    // Register update control
    wire writeBackEn = (state == EXECUTE && !isBranch && ! isStore);


    wire [31:0] writeBackData = (isJAL | isJALR)? PCplus4:
                                         isAUIPC? PCplusImm:         
                                           isLUI? Uimm:
                                                  aluOut; 

    wire [31:0] nextPC =          isJALR ? {aluPlus[31:1],1'b0} :
        ((isBranch && takeBranch)||isJAL)? PCplusImm :
                                           PCplus4;



    `ifdef BENCH    // clear registers on boot
        integer i;
        initial begin
            for(i=0; i<32; ++i) begin
                RegisterBank[i] = 0;
            end
        end
    `endif   


    // RISCV decoder

    // Instruction types
    wire isALUreg  =  (instr[6:0] == 7'b0110011);   // rd <- rs1 OP rs2   
    wire isALUimm  =  (instr[6:0] == 7'b0010011);   // rd <- rs1 OP Iimm
    wire isLUI     =  (instr[6:0] == 7'b0110111);   // rd <- Uimm   
    wire isLoad    =  (instr[6:0] == 7'b0000011);   // rd <- mem[rs1+Iimm]
    wire isAUIPC   =  (instr[6:0] == 7'b0010111);   // rd <- PC + Uimm
    wire isJALR    =  (instr[6:0] == 7'b1100111);   // rd <- PC+4; PC<-rs1+Iimm
    wire isJAL     =  (instr[6:0] == 7'b1101111);   // rd <- PC+4; PC<-PC+Jimm
    wire isBranch  =  (instr[6:0] == 7'b1100011);   // if(rs1 OP rs2) PC<-PC+Bimm
    wire isStore   =  (instr[6:0] == 7'b0100011);   // mem[rs1+Simm] <- rs2
    wire isSYSTEM  =  (instr[6:0] == 7'b1110011);   // special

    // Register pointers
    wire [4:0] rs2Id = instr[24:20];                    
    wire [4:0] rs1Id = instr[19:15];
    wire [4:0] rdId  = instr[11:7];    
    
    // Function codes
    wire [6:0] funct7 = instr[31:25];
    wire [2:0] funct3 = instr[14:12];

    // Immediate values
    wire [31:0] Iimm={{21{instr[31]}}, instr[30:20]};   
    wire [31:0] Uimm={    instr[31],   instr[30:12], {12{1'b0}}};
    wire [31:0] Simm={{21{instr[31]}}, instr[30:25],instr[11:7]};
    wire [31:0] Bimm={{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
    wire [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};


    // ALU
    wire [31:0] aluIn1 = rs1;
    wire [31:0] aluIn2 = isALUreg | isBranch ? rs2 : Iimm;
    wire [4:0]  shamt = isALUreg ? rs2: rs2Id;
    reg  [31:0] aluOut;

    // intermediates for optimization
    wire [31:0] aluPlus = aluIn1 + aluIn2;
    wire [32:0] aluMinus = {1'b0,aluIn1} - {1'b0,aluIn2};
    wire        EQ  = (aluMinus[31:0] == 0);
    wire        LTU = aluMinus[32];
    wire        LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
   
   // Flip a 32 bit word. Used by the shifter (a single shifter for left and right shifts, saves silicium !)
   function [31:0] flip32;
      input [31:0] x;
      flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7], 
		x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15], 
		x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
		x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
   endfunction
    
    wire [31:0] shifter_in = (funct3 == 3'b001) ? flip32(aluIn1) : aluIn1;
    wire [31:0] shifter = 
               $signed({funct7[5] & aluIn1[31], shifter_in}) >>> shamt;
    wire [31:0] leftshift = flip32(shifter);

    always @(*) begin
        case(funct3)
        3'b010:	aluOut = {31'b0, LT};                               //signed comparison (<)
        3'b011:	aluOut = {31'b0, LTU};                              //unsigned comparison (<)
        3'b001:	aluOut = leftshift;                                 //left shift
        3'b101: aluOut = shifter;
        3'b000:	aluOut = (funct7[5] & isALUreg)? (aluMinus[31:0]):
                                                 (aluPlus);         //ADD or SUB
        3'b110: aluOut = aluIn1 | aluIn2;                           //OR
        3'b111: aluOut = aluIn1 & aluIn2;                           //AND
        3'b100:	aluOut = aluIn1 ^ aluIn2;                           //XOR
        endcase
    end

    reg takeBranch;
    always @(*) begin
        case(funct3)
        3'b000:	takeBranch =  EQ;   // BEQ
        3'b001:	takeBranch = !EQ;   // BNE
        3'b100:	takeBranch =  LT;   // BLT
        3'b101:	takeBranch = !LT;   // BGE
        3'b110: takeBranch =  LTU;  // BLTU
        3'b111: takeBranch = !LTU;  // BGEU
        default: takeBranch = 1'b0;
        endcase
    end
   

    //`ifdef BENCH
    `ifdef SKIP_DEBUG
        always @(posedge clk) begin
            $display("PC=%0d takeBranch=%d nextPC=%d ",PC, takeBranch, nextPC);
            if(state == FETCH_INSTR) begin
                $display("FETCH_INSTR: instr=%b", MEM[PC[31:2]]);
            end
            if(state == FETCH_REGS) begin
                case (1'b1)
                    isALUreg: $display("FETCH_REGS: ALUreg rd=%d rs1=%d rs2=%d funct3=%b funct7=%b",rdId, rs1Id, rs2Id, funct3, funct7);
                    isALUimm: $display("FETCH_REGS: ALUimm rd=%d rs1=%d imm=%0d funct3=%b funct7=%b",rdId, rs1Id, Iimm, funct3, funct7);
                    isBranch: $display("FETCH_REGS: BRANCH takeBranch=%d rs1=%d rs2=%d funct3=%b Bimm=%b",takeBranch,rs1Id, rs2Id, funct3, Bimm);
                    isJAL:    $display("FETCH_REGS: JAL");
                    isJALR:   $display("FETCH_REGS: JALR");
                    isAUIPC:  $display("FETCH_REGS: AUIPC");
                    isLUI:    $display("FETCH_REGS: LUI");	
                    isLoad:   $display("FETCH_REGS: LOAD");
                    isStore:  $display("FETCH_REGS: STORE");
                    isSYSTEM: $display("FETCH_REGS: SYSTEM");
                endcase 
            end
            if(state== EXECUTE) begin
                $display("EXECUTE: rs1=%b rs2=%b",rs1,rs2);
            end
        end
    `endif

endmodule


module SOC (
        input  CLK,        
        input  RESET,      
        output [4:0] LEDS, 
        input  RXD,        
        output TXD  
    );
    
    Clockworks CW(.clock_in(CLK), .clock_out(clk));
    wire clk;

    Memory RAM(
      .clk(clk),
      .mem_addr(mem_addr),
      .mem_rdata(mem_rdata),
      .mem_rstrb(mem_rstrb)
    );
    wire [31:0] mem_addr;
    wire [31:0] mem_rdata;
    wire mem_rstrb;

    Processor CPU(
    .clk(clk),
    .resetn(RESET),
    .mem_addr(mem_addr), 
    .mem_rdata(mem_rdata), 
    .mem_rstrb(mem_rstrb),
    .x10_s(x10)
    );
    wire [31:0] x10;

    assign LEDS = x10[4:0];
    assign TXD  = 1'b0; // not used for now

endmodule