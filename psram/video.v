// 640x480@60 DVI out through the 1BitSquared 12-bit DVI PMOD (TFP410) on PMOD 1A+1B.
// Pixel clock 25.125 MHz (VESA: 25.175), 59.8 Hz frames, both sync pulses negative.
// The pins are registered in their IO cells; the clock pin is a DDR output
// inverted from clk_pix, so the TFP410 latches on its rising edge, mid data eye
// (as icebreaker-verilog-examples dvi-12bit does).
// For now a test pattern in the 640x400 image area (rows 40..439), black letterbox.
module VIDEO (
    input        clk_pix,
    output [3:0] dvi_r,
    output [3:0] dvi_g,
    output [3:0] dvi_b,
    output       dvi_clk,
    output       dvi_hs,
    output       dvi_vs,
    output       dvi_de
);
    // H: 640 active, 16 front porch, 96 sync, 48 back porch. V: 480, 10, 2, 33.
    reg [9:0] h = 10'd0, v = 10'd0;
    always @(posedge clk_pix) begin
        h <= h == 10'd799 ? 10'd0 : h + 1;
        if (h == 10'd799) v <= v == 10'd524 ? 10'd0 : v + 1;
    end

    wire active = h < 10'd640 && v < 10'd480;
    wire image  = v >= 10'd40 && v < 10'd440;
    wire hs = !(h >= 10'd656 && h < 10'd752);
    wire vs = !(v >= 10'd490 && v < 10'd492);

    // Test pattern: a white frame; above, 8 colour bars 64 px wide (h[8:6] = RGB)
    // then a grey ramp in 8 px steps; below, 16-step ramps 32 px wide in bands of
    // 32 rows: red, green, blue, grey.
    wire        frame = h == 10'd0 || h == 10'd639 || v == 10'd40 || v == 10'd439;
    wire [3:0]  ramp = h[8:5];
    wire [11:0] bars = h[9] ? {3{h[6:3]}} : {{4{h[8]}}, {4{h[7]}}, {4{h[6]}}};
    wire [11:0] ramps = v[6:5] == 2'd0 ? {ramp, 8'h00} : v[6:5] == 2'd1 ? {4'h0, ramp, 4'h0} :
                        v[6:5] == 2'd2 ? {8'h00, ramp} : {3{ramp}};
    wire [11:0] rgb = !active || !image ? 12'h000 : frame ? 12'hFFF : v < 10'd240 ? bars : ramps;

    SB_IO #(.PIN_TYPE(6'b01_0000)) clk_io (     // DDR: low on the rising edge, high on the falling
        .PACKAGE_PIN(dvi_clk), .D_OUT_0(1'b0), .D_OUT_1(1'b1), .OUTPUT_CLK(clk_pix)
    );
    SB_IO #(.PIN_TYPE(6'b01_0100)) data_io [14:0] (    // registered outputs
        .PACKAGE_PIN({dvi_r, dvi_g, dvi_b, dvi_hs, dvi_vs, dvi_de}),
        .D_OUT_0({rgb, hs, vs, active}),
        .OUTPUT_CLK(clk_pix)
    );
endmodule
