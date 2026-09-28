`include "clockworks.v"
`include "emitter_uart.v"
`include "pipe.v"
`include "uart_rx.v"


module Memory (
    input               clk,
    input      [31:0]   mem_addr,  // address to be read
    output reg [31:0]   mem_rdata, // data read from memory
    input   	        mem_rstrb,  // goes high when processor wants to read
    input      [31:0]   mem_wdata, // data to write to memory
    input      [3:0]	mem_wmask  // data write mask 1 bit per byte in word
    
);
    reg [31:0] MEM [0:1535]; // 1536 4-bytes words = 6 Kb of RAM in total

    wire [29:0] word_addr = mem_addr[31:2];

   always @(posedge clk) begin
      if(mem_rstrb) begin
            //$display("MEM: mem_add %d, mem_rdata %d", mem_addr[31:2], MEM[mem_addr[31:2]]);
         mem_rdata <= MEM[word_addr];
      end
      if(mem_wmask[0]) MEM[word_addr][ 7:0 ] <= mem_wdata[ 7:0 ];
      if(mem_wmask[1]) MEM[word_addr][15:8 ] <= mem_wdata[15:8 ];
      if(mem_wmask[2]) MEM[word_addr][23:16] <= mem_wdata[23:16];
      if(mem_wmask[3]) MEM[word_addr][31:24] <= mem_wdata[31:24];	 
   end


    `ifdef BENCH
        localparam slow_bit=12;
    `else
        localparam slow_bit=12+4;
    `endif

    // Memory-mapped IO in IO page, 1-hot addressing in word address.   
    localparam IO_LEDS_bit      = 0;  // W five leds
    localparam IO_UART_DAT_bit  = 1;        // W data to send (8 bits) 
    localparam IO_UART_CNTL_bit = 2;     // R status. bit 9: busy sending

    // Converts an IO_xxx_bit constant into an offset in IO page.
    function [31:0] IO_BIT_TO_OFFSET;
        input [31:0] bit;
        begin
        IO_BIT_TO_OFFSET = 1 << (bit + 2);
        end
    endfunction


    // code

   
    initial begin
       $readmemh("assemble.hexdump",MEM);
    end   

endmodule

// MUL=1: MUL/MULH/MULHSU/MULHU in one cycle (4 SB_MAC16s with synth_ice40 -dsp).
// DIV=1: DIV/DIVU/REM/REMU, one quotient bit per cycle (~340 LCs). Off by default:
// MUL alone is Zmmul (-march=rv32i_zmmul), and CoreMark runs no faster with DIV.
module Processor #(parameter MUL = 1, DIV = 0) (
    input 	            clk,
    input 	            resetn,
    output     [31:0]   mem_addr, 
    input      [31:0]   mem_rdata, 
    output 	            mem_rstrb,
    input               mem_rbusy,  // read data not ready yet: hold in WAIT_INSTR / WAIT_DATA
    output     [31:0]   mem_wdata,
    output     [3:0]	mem_wmask,
    input               mem_wbusy   // store not accepted yet: hold in STORE with wmask asserted
);


    // CPU state machine
    localparam FETCH_INSTR = 0;
    localparam WAIT_INSTR  = 1;
    localparam FETCH_REGS  = 2;
    localparam EXECUTE     = 3;
    localparam LOAD        = 4;
    localparam WAIT_DATA   = 5;
    localparam STORE       = 6;
    
    
    reg [2:0] state = FETCH_INSTR;

    always @(posedge clk) begin
        if(!resetn) begin
	        PC <= 0;
	        state <= FETCH_INSTR;
        end else begin
            if(writeBackEn && rdId != 0) begin
                RegisterBank[rdId] <= writeBackData;
                
                // For displaying what happens.
                // `ifdef BENCH	 
                //     if(state == EXECUTE ^ isLoad) begin
                //         $display("x%0d <= %b : d%d",rdId,writeBackData,writeBackData);
                //     end
                // `endif	
	        end

	        case(state)
	        FETCH_INSTR: begin
	            state <= WAIT_INSTR;
	        end
	        WAIT_INSTR: begin
                if(!mem_rbusy) begin
	                instr <= mem_rdata;
	                state <= FETCH_REGS;
                end
	        end
	        FETCH_REGS: begin
	            rs1 <= RegisterBank[rs1Id];
	            rs2 <= RegisterBank[rs2Id];
	            state <= EXECUTE;
	        end
	        EXECUTE: if(!divBusy) begin
                if(!isSYSTEM) begin
	                PC <= nextPC;
                end
	            state <= isLoad ? LOAD  : 
                         isStore? STORE :
                                  FETCH_INSTR;
                
                `ifdef BENCH      
                    if(isSYSTEM) $finish();
                `endif   

	        end
            LOAD: begin
                state <= WAIT_DATA;
            end
            WAIT_DATA: begin
                if(!mem_rbusy) begin
                    state <= FETCH_INSTR;
                end
	        end
            STORE: begin
                if(!mem_wbusy) begin
                    state <= FETCH_INSTR;
                end
	        end
	        endcase
            
        end
    end 


    // Registers
    reg [31:0] PC =0;               // program counter
    reg [31:0] instr;               // current instruction

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
    wire writeBackEn = (state == EXECUTE && !isBranch && ! isStore && !isLoad && !divBusy)|| (state == WAIT_DATA && !mem_rbusy); // isLoad only to help with sim viz


    wire [31:0] writeBackData = (isJAL | isJALR)? PCplus4:
                                         isAUIPC? PCplusImm:         
                                          isLoad? LOAD_data:
                                           isLUI? Uimm:
                                           isMul? mulOut:
                                           isDiv? divOut:
                                                  aluOut; 

    // PC update
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


    // Load instructions

    wire [15:0] LOAD_halfword = loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];
    wire  [7:0] LOAD_byte = loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

    wire mem_byteAccess     = funct3[1:0] == 2'b00;
    wire mem_halfwordAccess = funct3[1:0] == 2'b01;
    wire mem_MSB = mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15];
    wire LOAD_sign = !funct3[2] & (mem_MSB);    // LW,LBU,LHU

    wire [31:0] LOAD_data = mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
                        mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                                             mem_rdata ;

    // Store instructions
    assign mem_wdata[ 7: 0] = rs2[7:0];
    assign mem_wdata[15: 8] = loadstore_addr[0] ? rs2[7:0]  : rs2[15: 8]; 
    assign mem_wdata[23:16] = loadstore_addr[1] ? rs2[7:0]  : rs2[23:16];
    assign mem_wdata[31:24] = loadstore_addr[0] ? rs2[7:0]  :
			                  loadstore_addr[1] ? rs2[15:8] : rs2[31:24];  // maybe can be cleaned-up, higher bits will never be rs[0:7]?
    wire [3:0] STORE_wmask =
	       mem_byteAccess       ?
	            (loadstore_addr[1] ?
		          (loadstore_addr[0] ? 4'b1000 : 4'b0100) :         /// maybe simplify?
		          (loadstore_addr[0] ? 4'b0010 : 4'b0001)
                    ) :
	       mem_halfwordAccess   ?
	            (loadstore_addr[1] ? 4'b1100 : 4'b0011) :
              4'b1111;

    // Memmory interface
    wire [31:0] loadstore_addr = rs1 +(isStore? Simm:Iimm); // shared betwen load and store

    assign mem_addr = (state == WAIT_INSTR || state == FETCH_INSTR)? PC : loadstore_addr;
    assign mem_rstrb = (state == FETCH_INSTR || state == LOAD);
    assign mem_wmask = {4{(state == STORE)}} & STORE_wmask;


    // RISCV decoder
    // https://github.com/jameslzhu/riscv-card/blob/master/riscv-card.pdf
    //
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
   

    // M extension (funct7 = 0000001)
    wire isMul = MUL && isALUreg && funct7[0] && !funct3[2];
    wire isDiv = DIV && isALUreg && funct7[0] &&  funct3[2];

    // MUL: low word. MULH: s*s, MULHSU: s*u, MULHU: u*u, high word. Unsigned product
    // (4 SB_MAC16s), then signed high word = hi - (rs1<0 ? rs2 : 0) - (rs2<0 ? rs1 : 0).
    wire [63:0] mulP  = rs1 * rs2;
    wire [31:0] mulHi = mulP[63:32] - ({32{funct3[1:0] != 2'b11 & rs1[31]}} & rs2)
                                    - ({32{funct3[1:0] == 2'b01 & rs2[31]}} & rs1);
    wire [31:0] mulOut = |funct3[1:0] ? mulHi : mulP[31:0];

    // DIV/DIVU/REM/REMU on magnitudes, restoring, one bit per cycle: EXECUTE is held
    // 33 cycles (load, then 32 steps). The dividend shifts out of quo as the quotient
    // shifts in. Divide by zero gives quo = ~0 and rem = dividend, as the spec wants.
    reg  [31:0] quo, rem;
    reg  [5:0]  divCnt;
    wire        divSigned = !funct3[0];
    wire        dvsrPos = !(divSigned & rs2[31]);   // subtract rs2, or add it if negative
    wire [33:0] divDiff = {1'b0, rem, quo[31]} + {2'b11, rs2 ^ {32{dvsrPos}}} + dvsrPos;
    wire        divBusy = isDiv && divCnt != 0;
    wire        divNeg  = divSigned & (funct3[1] ? rs1[31] : (rs1[31] ^ rs2[31]) & |rs2);
    wire [31:0] divRes  = funct3[1] ? rem : quo;
    wire [31:0] divOut  = divNeg ? -divRes : divRes;

    always @(posedge clk) begin
        if(state == FETCH_REGS) divCnt <= 33;
        if(state == EXECUTE && divBusy) begin
            divCnt <= divCnt - 1;
            if(divCnt == 33) begin
                quo  <= divSigned & rs1[31] ? -rs1 : rs1;
                rem  <= 0;
            end else begin
                quo  <= {quo[30:0], !divDiff[33]};
                rem  <= divDiff[33] ? {rem[30:0], quo[31]} : divDiff[31:0];
            end
        end
    end

    //`ifdef BENCH
    `ifdef SKIP_DEBUG
        always @(posedge clk) begin
            $display("PC=%0d takeBranch=%d nextPC=%d ",PC, takeBranch, nextPC);
            if(state == FETCH_INSTR) begin
                //$display("FETCH_INSTR: instr=%b", MEM[PC[31:2]]);
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

module free_cnt(input clk, input resetn, output [31:0] cnt);    

    reg [31:0] counter = 0;
    assign cnt = counter;

    always @(posedge clk, negedge resetn) begin
        if(!resetn) begin
            counter <= 0;
        end else begin
            counter <= counter+1;
        end
    end
endmodule

// Mandelbrot iteration count for one point C, in Q4.27 fixed point (|values| < 16).
// One 32x32 multiplier (4 DSPs) is shared by the three products, so an iteration
// takes 3 cycles: Zr*Zr, Zi*Zi, then Zr*Zi and the update. `iteration` counts
// down from max_it and is 0 when C stayed in the set.
// Points inside the main cardioid or the period-2 bulb never escape, so they are
// found first with 4 more products and skip the iterations:
//   q = (x-1/4)^2 + y^2, cardioid: q (q + x - 1/4) <= y^2/4, bulb: (x+1)^2 + y^2 <= 1/16
module Mandelbrot #(parameter mandel_shift=27)
                    (input clk, input resetn, input valid, output reg ready,
                     input signed [31:0] Cr, input signed [31:0] Ci,
                     input [15:0] max_it, output reg [15:0] iteration);

    localparam ONE = 1 << mandel_shift;

    reg signed [31:0] Zr, Zi, q;
    reg        [35:0] Zrr, Zii;     // squares, up to 16*16
    reg        [2:0]  phase;        // 0-2: iteration, 4-7: cardioid/bulb check
    reg               cardioid;

    wire signed [31:0] a = Cr - ONE/4;
    wire signed [31:0] b = Cr + ONE;
    reg  signed [31:0] ma, mb;
    always @* case(phase)
        0:       begin ma = Zr; mb = Zr;    end
        2:       begin ma = Zr; mb = Zi;    end
        4:       begin ma = a;  mb = a;     end
        6:       begin ma = q;  mb = q + a; end
        7:       begin ma = b;  mb = b;     end
        default: begin ma = Zi; mb = Zi;    end   // 1, 5
    endcase
    wire signed [63:0] p = ma * mb;
    wire        [35:0] sq = p >>> mandel_shift;
    wire signed [31:0] Zri = p >>> (mandel_shift-1);   // 2*Zr*Zi
    wire out_of_set = {1'b0, Zrr} + Zii > (4 << mandel_shift);
    // The check's products fit when |Cr|, |Ci| < 2; farther out the point escapes anyway.
    wire near = (&Cr[31:28] | ~|Cr[31:28]) & (&Ci[31:28] | ~|Ci[31:28]);

    always @(posedge clk) begin
        if(!resetn) begin
            ready <= 1;
        end else if(ready) begin
            if (valid) begin
                Zr <= Cr; Zi <= Ci;
                iteration <= max_it;
                phase <= near ? 4 : 0;
                ready <= 0;
            end
        end else case(phase)
            0: begin Zrr <= sq; phase <= 1; end
            1: begin Zii <= sq; phase <= 2; end
            2: begin
                if(!out_of_set & iteration>0) begin
                    Zr <= Zrr - Zii + Cr;
                    Zi <= Zri + Ci;
                    iteration <= iteration-1;
                    phase <= 0;
                end else begin
                    ready <= 1;
                end
            end
            4: begin q <= sq; phase <= 5; end
            5: begin q <= q + sq; Zii <= sq; phase <= 6; end
            6: begin cardioid <= p <= $signed({1'b0, Zii, 25'b0}); phase <= 7; end
            default: begin
                if (cardioid | sq + Zii <= ONE/16) begin
                    iteration <= 0;
                    ready <= 1;
                end else
                    phase <= 0;
            end
        endcase
    end
endmodule


module SOC (
        input  CLK,        
        input  RESET,      
        output LEDR_N,      // LEDS[4], on the iCEBreaker (PMOD 2 may hold the PSRAM board)
        output LEDG_N,      // LEDS[0]
        input  RXD,     
        output P1A1,
        output TXD  
    );

    assign P1A1 = TXD;

    reg [4:0] LEDS = 5'b0;
    assign LEDG_N = !LEDS[0];
    assign LEDR_N = !LEDS[4];
    
    Clockworks CW(.clock_in(CLK), .clock_out(clk),.reset_ext(RESET),.resetn(resetn)); // Fin 12Mhz,  Fout 16Mhz, delayed reset and POR
    wire resetn;
    wire clk;

    Mandelbrot mb(.clk(clk), .resetn(resetn),.valid(mandel_valid),.ready(mandel_ready),.Cr(Cr),.Ci(Ci),.max_it(mandel_max_it),.iteration(mandel_iteration));
    wire mandel_valid = isIO & mem_wstrb & mem_wordaddr[IO_MANDEL_CTRL];
    reg signed [31:0] Cr, Ci;
    wire mandel_ready;
    wire [15:0] mandel_iteration;
    reg  [15:0] mandel_max_it = 31;


    // ## DEBUG
    // always @(posedge clk) begin
    //     if(isIO & mem_wstrb ) begin
	//         $display("IO %h",mem_wordaddr);
    //     end
    // end
    // DEBUG

    always @(posedge clk) begin
        if(isIO & mem_wstrb & mem_wordaddr[IO_MANDEL_CR]) begin
	        Cr <= mem_wdata;
        end
        if(isIO & mem_wstrb & mem_wordaddr[IO_MANDEL_CI]) begin
	        Ci <= mem_wdata;
        end
        if(isIO & mem_wstrb & mem_wordaddr[IO_MANDEL_IT]) begin
	        mandel_max_it <= mem_wdata;
        end
    end

    wire [31:0] RAM_rdata;
    wire [29:0] mem_wordaddr = mem_addr[31:2];
    wire isIO  = mem_addr[22];
    wire isRAM = !isIO;
    wire mem_wstrb = |mem_wmask;

    wire [31:0] mem_addr;
    wire [31:0] mem_rdata;
    wire mem_rstrb;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire [31:0] counter;
    

    wire [31:0] IO_rdata =
        mem_wordaddr[IO_UART_CNTL_bit]  ? { 22'b0, !uart_ready, 9'b0} :
        mem_wordaddr[IO_COUNTER_bit]    ? counter:
        mem_wordaddr[IO_MANDEL_CTRL]    ? mandel_ready:
        mem_wordaddr[IO_MANDEL_IT]      ? mandel_iteration:
        mem_wordaddr[IO_UART_RX_bit]    ? {23'b0, rx_full, rx_data}
                                        : 32'b0;

    // Read data comes a cycle after the strobe, when the address may have moved
    // on (ProcessorPipe): the region and the IO value are latched on the strobe.
    reg        rd_ram;
    reg [31:0] IO_q;
    always @(posedge clk) if (mem_rstrb) begin rd_ram <= isRAM; IO_q <= IO_rdata; end
    assign mem_rdata = rd_ram ? RAM_rdata : IO_q;


    Memory RAM(
      .clk(clk),
      .mem_addr(mem_addr),
        .mem_rdata(RAM_rdata),
        .mem_rstrb(isRAM & mem_rstrb),
      .mem_wdata(mem_wdata),
        .mem_wmask({4{isRAM}}&mem_wmask)
    );

`ifdef PIPE
    ProcessorPipe CPU(
`else
    Processor CPU(
`endif
    .clk(clk),
        .resetn(resetn),
    .mem_addr(mem_addr),
    .mem_rdata(mem_rdata),
    .mem_rstrb(mem_rstrb),
    .mem_rbusy(1'b0),
    .mem_wdata(mem_wdata),
    .mem_wmask(mem_wmask),
    .mem_wbusy(1'b0)
    );

    // Memory-mapped IO in IO page, 1-hot addressing in word address.
    localparam IO_LEDS_bit = 0;  
    localparam IO_UART_DAT_bit  = 1;        // W data to send (8 bits) 
    localparam IO_UART_CNTL_bit = 2;     // R status. bit 9: busy sending
    localparam IO_COUNTER_bit   = 3;
    localparam IO_MANDEL_CTRL   = 4;
    localparam IO_MANDEL_CR     = 5;
    localparam IO_MANDEL_CI     = 6;
    localparam IO_MANDEL_IT     = 7;     // R iterations left, W max iterations
    localparam IO_UART_RX_bit   = 8;     // R {valid, byte}; reading clears valid


    always @(posedge clk) begin
        if(isIO & mem_wstrb & mem_wordaddr[IO_LEDS_bit]) begin
	        LEDS <= mem_wdata;
        end
    end

    wire uart_valid = isIO & mem_wstrb & mem_wordaddr[IO_UART_DAT_bit];
    wire uart_ready;

    corescore_emitter_uart #(
        .clk_divider(4)      // 12 MHz / 4 = 3 Mbaud (exact on the FT2232H)
    ) UART(
        .i_clk(clk),
        .i_rst(resetn),
        .i_data(mem_wdata[7:0]),
        .i_valid(uart_valid),
        .o_ready(uart_ready),
        .o_uart_tx(TXD)      			       
    );

    // Free running counter at Fin
    free_cnt f_cnt1(.clk(clk), .resetn(resetn), .cnt(counter));

    // One-byte receive buffer. IO_q latches it on the load strobe, which also clears it.
    wire [7:0] rx_data;
    wire       rx_valid;
    reg        rx_full = 1'b0;
    wire       rx_rd = isIO & mem_rstrb & mem_wordaddr[IO_UART_RX_bit];

    UART_RX #(.CLKS_PER_BIT(4)) UART_RX(.clk(clk), .rx(RXD), .data(rx_data), .valid(rx_valid));

    always @(posedge clk) begin
        if (rx_valid) rx_full <= 1'b1;
        else if (rx_rd) rx_full <= 1'b0;
    end

    // DEBUG terminal
    `ifdef BENCH
    always @(posedge clk) begin
        if(uart_valid) begin
        $write("%c", mem_wdata[7:0] );
        $fflush(32'h8000_0001);
        end
    end
    `endif   

endmodule