// Behavioural model of ESP-PSRAM64H / APS6404L in *single* SPI mode.
// Models: 0x9F Read-ID, tCO (clock-to-output), tCEM (max CS# low), tCPH (min CS# high).
`timescale 1ns/1ps
module psram_model #(
    parameter real TCO  = 8.0,   // SCLK falling edge -> SO valid, at the device
    parameter real TCEM = 8000.0,// max CE# low time (ns)  -- 8 us
    parameter real TCPH = 18.0   // min CE# high time (ns)
)(
    input  ce_n,
    input  sclk,
    input  si,
    output so
);
    reg so_r = 1'bz;
    assign #(0) so = ce_n ? 1'bz : so_r;

    // 8 ID bytes: MFID=0x0D, KGD=0x5D, then 6 EID bytes
    reg [63:0] ID = 64'h0D_5D_DE_AD_BE_EF_12_34;

    integer bitpos;          // bits shifted in since CE# fell
    reg [7:0] cmd;
    reg       reading;

    time t_ce_fall, t_ce_rise;
    integer n_tcem_viol = 0, n_tcph_viol = 0;

    initial begin t_ce_rise = 0; reading = 0; bitpos = 0; end

    always @(negedge ce_n) begin
        t_ce_fall = $time;
        if (t_ce_rise != 0 && (t_ce_fall - t_ce_rise) < TCPH) begin
            n_tcph_viol = n_tcph_viol + 1;
            $display("[%0t] PSRAM VIOLATION tCPH: CE# high only %0t ns (min %0.1f)",
                     $time, t_ce_fall - t_ce_rise, TCPH);
        end
        bitpos = 0; reading = 0; cmd = 8'h00; so_r = 1'bz;
    end

    always @(posedge ce_n) begin
        t_ce_rise = $time;
        if ((t_ce_rise - t_ce_fall) > TCEM) begin
            n_tcem_viol = n_tcem_viol + 1;
            $display("[%0t] PSRAM VIOLATION tCEM: CE# low for %0t ns (max %0.1f) -- refresh lost, DATA CORRUPT",
                     $time, t_ce_rise - t_ce_fall, TCEM);
        end
        so_r = 1'bz;
    end

    // Device samples SI on rising edge of SCLK
    always @(posedge sclk) if (!ce_n) begin
        if (bitpos < 8) cmd = {cmd[6:0], si};
        bitpos = bitpos + 1;
        if (bitpos == 8 && cmd == 8'h9F) reading = 1;  // Read ID: 24 addr bits follow
    end

    // Device launches SO on falling edge of SCLK, TCO later
    always @(negedge sclk) if (!ce_n) begin
        if (reading && bitpos >= 32 && bitpos < 32+64)
            so_r <= #(TCO) ID[63 - (bitpos-32)];
        else if (reading && bitpos >= 32)
            so_r <= #(TCO) 1'b0;
    end
endmodule
