`include "clockworks.v"

module SOC (
       input  CLK,        
       input  RESET,      
       output reg [4:0] LEDS, 
       input  RXD,        
       output TXD  
   );
  
   wire clkd;
   
   assign TXD  = 1'b0; // not used for now

   Clockworks #(.SLOW(22))CW(.clock_in(CLK), .clock_out(clkd));


    // Registers
    reg [31:0] MEM [0:255];     // RAM
    reg [31:0] PC =0;              // program counter
    reg [31:0] instr;           // current instruction

    reg [31:0] RegisterBank [0:31];
    reg [31:0] rs1;
    reg [31:0] rs2;
    wire [31:0] writeBackData =  (isJAL | isJALR)? (PC+4) : aluOut; 
    wire writeBackEn = (state == EXECUTE && (isALUreg || isALUimm || isJALR || isJAL));
    wire [31:0] nextPC = (isJAL ? PC+Jimm : (isJALR ? rs1+Iimm : (PC+4)));

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
    wire isBranch  =  (instr[6:0] == 7'b1100011); // if(rs1 OP rs2) PC<-PC+Bimm
    wire isJALR    =  (instr[6:0] == 7'b1100111);   // rd <- PC+4; PC<-rs1+Iimm
    wire isJAL     =  (instr[6:0] == 7'b1101111);   // rd <- PC+4; PC<-PC+Jimm
    wire isAUIPC   =  (instr[6:0] == 7'b0010111);   // rd <- PC + Uimm
    wire isLUI     =  (instr[6:0] == 7'b0110111);   // rd <- Uimm   
    wire isLoad    =  (instr[6:0] == 7'b0000011);   // rd <- mem[rs1+Iimm]
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


    // CPU state machine
    localparam FETCH_INSTR = 0;
    localparam FETCH_REGS  = 1;
    localparam EXECUTE     = 2;
    reg [1:0] state = FETCH_INSTR;

    always @(posedge clkd) begin
        if(!RESET) begin
	        PC <= 0;
	        state <= FETCH_INSTR;
        end else begin
            if(writeBackEn && rdId != 0) begin
                RegisterBank[rdId] <= writeBackData;
                
                // For displaying what happens.
                if(rdId == 1) begin
                    LEDS <= writeBackData;
                end
                `ifdef BENCH	 
                        $display("x%0d <= %b : d%d",rdId,writeBackData,writeBackData);
                `endif	
	        end

	        case(state)
	        FETCH_INSTR: begin
	            instr <= MEM[PC[31:2]];
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

    // ALU
    wire [31:0] aluIn1 = rs1;
    wire [31:0] aluIn2 = isALUreg ? rs2 : Iimm;
    wire [4:0]  shamt = isALUreg ? rs2: rs2Id;
    reg  [31:0] aluOut;
    always @(*) begin
        case(funct3)
        3'b000:	aluOut = (funct7[5] & isALUreg)? (aluIn1-aluIn2):(aluIn1+aluIn2);   //ADD or SUB
        3'b001:	aluOut = aluIn1 << shamt;                                           //left shift
        3'b010:	aluOut = $signed(aluIn1) < $signed(aluIn2);                         //signed comparison (<)
        3'b011:	aluOut = aluIn1 < aluIn2;                                           //unsigned comparison (<)
        3'b100:	aluOut = aluIn1 ^ aluIn2;                                           //XOR
        3'b101:	aluOut = (funct7[5])? ($signed(aluIn1) >>> shamt):($signed(aluIn1)>>shamt);     //LogicalRShift or AritimeticRShift
        3'b110: aluOut = aluIn1 | aluIn2;                                           //OR
        3'b111: aluOut = aluIn1 & aluIn2;                                           //AND
        endcase
    end
    


    // debug
   `include "riscv_assembly.v"
    integer L0_= 16;
    initial begin
        ADDI(x3,zero,0);
	    ADDI(x2,zero,1);
        ADDI(x1,zero,0);
        ADDI(x1,zero,1);
        Label(L0_);
        ADD(x1,x2,x3);
        ADDI(x3,x2,0);
        ADDI(x2,x1,0);
	    JAL(x0,LabelRef(L0_));
        EBREAK();
        endASM();
    end
   

    `ifdef BENCH   
        always @(posedge clkd) begin
            //$display("PC=%0d, writeback:%b writedata:%b",PC,writeBackEn,writeBackData);
            if(state == FETCH_INSTR) begin
                //$display("FETCH_INSTR: instr=%b", MEM[PC]);
            end
            if(state == FETCH_REGS) begin
                case (1'b1)
                    isALUreg: $display("FETCH_REGS: ALUreg rd=%d rs1=%d rs2=%d funct3=%b funct7=%b",rdId, rs1Id, rs2Id, funct3, funct7);
                    isALUimm: $display("FETCH_REGS: ALUimm rd=%d rs1=%d imm=%0d funct3=%b funct7=%b",rdId, rs1Id, Iimm, funct3, funct7);
                    isBranch: $display("FETCH_REGS: BRANCH");
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
                //$display("EXECUTE: rs1=%b rs2=%b",rs1,rs2);
            end
    end
`endif


endmodule
