`include "clockworks.v"

module SOC (
       input  CLK,        
       input  RESET,      
       output [4:0] LEDS, 
       input  RXD,        
       output TXD  
   );
  
   wire clkd;
   
   assign TXD  = 1'b0; // not used for now

   Clockworks #(.SLOW(22))CW(.clock_in(CLK), .clock_out(clkd));


    // Registers
    reg [31:0] MEM [0:255];     // RAM
    reg [31:0] PC;              // program counter
    reg [31:0] instr;           // current instruction
    initial begin
        PC = 0;
        // add x0, x0, x0
        //                   rs2   rs1  add  rd   ALUREG
        instr = 32'b0000000_00000_00000_000_00000_0110011;
        // add x1, x0, x0
        //                    rs2   rs1  add  rd  ALUREG
        MEM[0] = 32'b0000000_00000_00000_000_00001_0110011;
        // sub x3, x2, x1
        //                    rs2   rs1  add  rd  ALUREG
        MEM[0] = 32'b0100000_00011_00010_000_00001_0110011;
        // addi x1, x1, 1
        //             imm         rs1  add  rd   ALUIMM
        MEM[1] = 32'b000000000001_00001_000_00001_0010011;
        // addi x1, x1, 1
        //             imm         rs1  add  rd   ALUIMM
        MEM[2] = 32'b000000000001_00001_000_00001_0010011;
        // addi x1, x1, 1
        //             imm         rs1  add  rd   ALUIMM
        MEM[3] = 32'b000000000001_00001_000_00001_0010011;
        // addi x1, x1, 1
        //             imm         rs1  add  rd   ALUIMM
        MEM[4] = 32'b000000000001_00001_000_00001_0010011;
        // lw x2,0(x1)
        //             imm         rs1   w   rd   LOAD
        MEM[5] = 32'b000000000000_00001_010_00010_0000011;
        // sw x2,0(x1)
        //             imm   rs2   rs1   w   imm  STORE
        MEM[6] = 32'b000000_00010_00001_010_00000_0100011;

        // ebreak
        //                                        SYSTEM
        MEM[7] = 32'b000000000001_00000_000_00000_1110011;  
    end
   
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

    // state machine
    always @(posedge clkd) begin
        if(!RESET) begin
	        PC <= 0;
	        instr <= 32'b0000000_00000_00000_000_00000_0110011; // NOP = ADD_0
        end else if(!isSYSTEM) begin
	        instr <= MEM[PC];
	        PC <= PC+1;
        end
        `ifdef BENCH      
            if(isSYSTEM) $finish();
        `endif      
    end

    // debug
    assign LEDS = isSYSTEM ? 31 : {PC[0],isALUreg,isALUimm,isStore,isLoad};

    `ifdef BENCH   
        always @(posedge clkd) begin
            $display("PC=%0d",PC);
            case (1'b1)
	            isALUreg: $display("ALUreg rd=%d rs1=%d rs2=%d funct3=%b funct3=%b",rdId, rs1Id, rs2Id, funct3, funct7);
	            isALUimm: $display("ALUimm rd=%d rs1=%d imm=%0d funct3=%b",rdId, rs1Id, Iimm, funct3);
	            isBranch: $display("BRANCH");
	            isJAL:    $display("JAL");
	            isJALR:   $display("JALR");
	            isAUIPC:  $display("AUIPC");
	            isLUI:    $display("LUI");	
	            isLoad:   $display("LOAD");
	            isStore:  $display("STORE");
	            isSYSTEM: $display("SYSTEM");
            endcase 
    end
`endif


endmodule
