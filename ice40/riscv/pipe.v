// Pipelined RV32I (+ Zmmul with MUL=1), same ports as Processor. DIV is not supported.
//   F  the fetch request goes out (mem_addr, mem_rstrb)
//   D  the instruction arrives on mem_rdata and its registers are read (EBR, 1 cycle)
//   E  execute and write back. Loads and stores use the bus here. A taken branch
//      or a jump loads the target into fpc and drops the two instructions fetched
//      behind it (2 bubbles; driving mem_addr with the target directly would save
//      one, but put the branch compare on the SoC's address decode: -4 MHz).
// A fetch goes out every cycle the bus is free, so ALU code runs at 1 CPI. A load
// writes back a cycle later (W), while the next instruction waits in E. The last
// register write is forwarded, which covers every read the EBR can miss.
// Bus: one request per cycle, read data the next cycle or later while mem_rbusy.
// Nothing new is requested while mem_rbusy; a store stays on the bus while mem_wbusy.
module ProcessorPipe #(parameter MUL = 1, DIV = 0) (
    input             clk,
    input             resetn,
    output     [31:0] mem_addr,
    input      [31:0] mem_rdata,
    output            mem_rstrb,
    input             mem_rbusy,
    output     [31:0] mem_wdata,
    output     [3:0]  mem_wmask,
    input             mem_wbusy
);
    reg [31:0] fpc;           // fetch in flight (pend) or next fetch
    reg        pend = 0;      // an instruction arrives this cycle
    reg [31:0] ipc, instr;    // E stage
    reg        ev = 0;        // E holds an instruction
    reg        ldW = 0;       // load data arrives this cycle, E waits
    reg [4:0]  ld_rd;
    reg [2:0]  ld_f3;
    reg [1:0]  ld_a;
    reg [31:0] wb_val;        // last register write,
    reg        fwd1 = 0, fwd2 = 0;  // ...forwarded to E's rs1/rs2

    reg [31:0] RF [0:31];
    reg [31:0] rf1, rf2;
    `ifdef BENCH
        integer i;
        initial for (i = 0; i < 32; i = i + 1) RF[i] = 0;
    `endif

    // Decode (E)
    wire isALUreg = instr[6:0] == 7'b0110011;
    wire isALUimm = instr[6:0] == 7'b0010011;
    wire isLUI    = instr[6:0] == 7'b0110111;
    wire isLoad   = instr[6:0] == 7'b0000011;
    wire isAUIPC  = instr[6:0] == 7'b0010111;
    wire isJALR   = instr[6:0] == 7'b1100111;
    wire isJAL    = instr[6:0] == 7'b1101111;
    wire isBranch = instr[6:0] == 7'b1100011;
    wire isStore  = instr[6:0] == 7'b0100011;
    wire isSYSTEM = instr[6:0] == 7'b1110011;
    wire [4:0] rs1Id = instr[19:15], rs2Id = instr[24:20], rdId = instr[11:7];
    wire [6:0] funct7 = instr[31:25];
    wire [2:0] funct3 = instr[14:12];
    wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
    wire [31:0] Uimm = {instr[31:12], 12'b0};
    wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
    wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

    wire [31:0] rs1 = fwd1 ? wb_val : rf1;
    wire [31:0] rs2 = fwd2 ? wb_val : rf2;

    // Control
    wire stall  = mem_rbusy;                         // freezes everything
    wire exE    = ev && !ldW;                        // E executes this cycle
    wire memE   = exE && (isLoad || isStore);        // ...and uses the bus
    wire waitW  = memE && isStore && mem_wbusy;
    wire doneNW = !ev || !ldW && !isSYSTEM;          // E frees up (wbusy aside)
    wire done   = doneNW && !waitW;
    wire redirect = exE && (isJAL || isJALR || isBranch && takeBranch);

    wire [31:0] PCplusImm = ipc + (isJAL ? Jimm : isAUIPC ? Uimm : Bimm);
    wire [31:0] fpc4 = fpc + 4;
    wire [31:0] fa = pend && doneNW ? fpc4 : fpc;       // next fetch in program order
    wire [31:0] target = isJALR ? {aluPlus[31:1], 1'b0} : PCplusImm;

    assign mem_addr  = memE ? aluPlus : fa;
    assign mem_rstrb = !stall && (!memE || isLoad);
    assign mem_wmask = {4{memE && isStore && !stall}} & STORE_wmask;

    // Write back: E, or the load data in W
    wire [31:0] result = isJAL | isJALR ? ipc + 4 :
                         isAUIPC ? PCplusImm :
                         isLUI   ? Uimm :
                         isMul   ? mulOut : aluOut;
    wire [4:0]  wa = ldW ? ld_rd : rdId;
    wire [31:0] wd = ldW ? LOAD_data : result;
    wire we = !stall && |wa && (ldW || exE && !isBranch && !isStore && !isLoad && !isSYSTEM);

    // The EBR reads an instruction's registers as it enters E; a write in that same
    // cycle or while it waits (load W) is taken from wb_val instead.
    wire [4:0] ra1 = done ? mem_rdata[19:15] : rs1Id;
    wire [4:0] ra2 = done ? mem_rdata[24:20] : rs2Id;
    always @(posedge clk) begin
        if (we) begin
            RF[wa] <= wd;
            wb_val <= wd;
        end
        if (!stall && done) begin
            rf1 <= RF[mem_rdata[19:15]];
            rf2 <= RF[mem_rdata[24:20]];
        end
        if (!stall && (we || done)) begin
            fwd1 <= we && wa == ra1;
            fwd2 <= we && wa == ra2;
        end
        if (!resetn) begin
            fpc <= 0; pend <= 0; ev <= 0; ldW <= 0;
        end else if (!stall) begin
            if (!waitW) fpc <= redirect ? target : fa;
            pend <= !memE && !redirect;     // the fetch made alongside a redirect is dropped
            ldW  <= memE && isLoad;
            if (done) begin
                ev    <= pend && !redirect;
                instr <= mem_rdata;
                ipc   <= fpc;
            end
            {ld_rd, ld_f3, ld_a} <= {rdId, funct3, aluPlus[1:0]};
            `ifdef BENCH
                if (exE && isSYSTEM) $finish();
            `endif
        end
    end

    // Loads (W: ld_* hold the load's fields)
    wire [15:0] LOAD_h = ld_a[1] ? mem_rdata[31:16] : mem_rdata[15:0];
    wire [7:0]  LOAD_b = ld_a[0] ? LOAD_h[15:8] : LOAD_h[7:0];
    wire        LOAD_s = !ld_f3[2] & (ld_f3[0] ? LOAD_h[15] : LOAD_b[7]);
    wire [31:0] LOAD_data = ld_f3[1:0] == 2'b00 ? {{24{LOAD_s}}, LOAD_b} :
                            ld_f3[1:0] == 2'b01 ? {{16{LOAD_s}}, LOAD_h} : mem_rdata;

    // Stores: sb/sh data replicated over the byte lanes
    wire [1:0] sa = aluPlus[1:0];
    assign mem_wdata = {sa[0] ? rs2[7:0] : sa[1] ? rs2[15:8] : rs2[31:24],
                        sa[1] ? rs2[7:0] : rs2[23:16],
                        sa[0] ? rs2[7:0] : rs2[15:8],
                        rs2[7:0]};
    wire [3:0] STORE_wmask = funct3[1:0] == 2'b00 ? 4'b0001 << sa :
                             funct3[1:0] == 2'b01 ? (sa[1] ? 4'b1100 : 4'b0011) : 4'b1111;

    // ALU. The adder also makes load/store and JALR addresses. EQ is a direct
    // compare (no carry chain). LT/LTU need the subtract's borrow, which arrives
    // late off the 32-bit carry chain: takeBranch is precomputed for both possible
    // values of the borrow (from signs + funct3 alone, in parallel with the carry),
    // and only a final mux picks one once the borrow lands (as in fastercore).
    wire [31:0] aluIn2 = isALUreg | isBranch ? rs2 : isStore ? Simm : Iimm;
    wire [4:0]  shamt  = isALUreg ? rs2[4:0] : rs2Id;
    wire [31:0] aluPlus  = rs1 + aluIn2;
    wire [32:0] aluMinus = {1'b0, rs1} - {1'b0, aluIn2};
    wire        EQ    = rs1 == aluIn2;
    wire        signD = rs1[31] ^ aluIn2[31];
    wire        LTU = aluMinus[32];
    wire        LT  = signD ? rs1[31] : aluMinus[32];

    function [31:0] flip32(input [31:0] x);
        integer k;
        for (k = 0; k < 32; k = k + 1) flip32[k] = x[31 - k];
    endfunction
    wire [31:0] shifter_in = funct3 == 3'b001 ? flip32(rs1) : rs1;
    wire [31:0] shifter    = $signed({funct7[5] & rs1[31], shifter_in}) >>> shamt;

    reg [31:0] aluOut;
    always @(*) case (funct3)
        3'b000: aluOut = funct7[5] & isALUreg ? aluMinus[31:0] : aluPlus;
        3'b001: aluOut = flip32(shifter);
        3'b010: aluOut = {31'b0, LT};
        3'b011: aluOut = {31'b0, LTU};
        3'b100: aluOut = rs1 ^ aluIn2;
        3'b101: aluOut = shifter;
        3'b110: aluOut = rs1 | aluIn2;
        3'b111: aluOut = rs1 & aluIn2;
    endcase

    function branchTaken(input [2:0] f3, input eq, input lt, input ltu);
        case (f3)
            3'b000:  branchTaken =  eq;
            3'b001:  branchTaken = !eq;
            3'b100:  branchTaken =  lt;
            3'b101:  branchTaken = !lt;
            3'b110:  branchTaken =  ltu;
            3'b111:  branchTaken = !ltu;
            default: branchTaken = 1'b0;
        endcase
    endfunction
    // Computed for both values of the borrow bit (aluMinus[32]) so this runs
    // alongside the carry chain instead of after it; see the comment above.
    (* keep *) wire tb1 = branchTaken(funct3, EQ, signD ? rs1[31] : 1'b1, 1'b1);
    (* keep *) wire tb0 = branchTaken(funct3, EQ, signD ? rs1[31] : 1'b0, 1'b0);
    wire takeBranch = aluMinus[32] ? tb1 : tb0;

    // MUL/MULH/MULHSU/MULHU, as in Processor
    wire isMul = MUL && isALUreg && funct7[0] && !funct3[2];
    wire [63:0] mulP  = rs1 * rs2;
    wire [31:0] mulHi = mulP[63:32] - ({32{funct3[1:0] != 2'b11 & rs1[31]}} & rs2)
                                    - ({32{funct3[1:0] == 2'b01 & rs2[31]}} & rs1);
    wire [31:0] mulOut = |funct3[1:0] ? mulHi : mulP[31:0];
endmodule
