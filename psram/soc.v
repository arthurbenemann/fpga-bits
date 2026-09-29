// RISC-V core from ../riscv with the PSRAM mapped into its address space.
//   0x000000-0x1FFFFF  BRAM (6 KB populated)
//   0x200000-0x3FFFFF  framebuffer, 320x200 bytes (64 KB populated), with VIDEO
//   0x400000-0x7FFFFF  IO page, same map as the riscv/ SOC
//   0x800000-0xFFFFFF  PSRAM, 8 MB
// With VIDEO defined, 640x480 DVI out (video.v) and a fixed clock plan.
// Build with -I../riscv; riscv.v also defines its own SOC top, which goes unused here.
`include "riscv.v"
`include "psram_spi.v"
`include "psram_bus.v"
`include "uart_fifo.v"
`include "flash_spi.v"
`ifdef VIDEO
`include "video.v"
`endif

module PSRAM_SOC (
    input            CLK,
    input            RESET,
    output           LEDR_N,    // LEDS[4], on the iCEBreaker itself (PMOD 2 holds the PSRAM)
    output           LEDG_N,    // LEDS[0]
    input            RXD,
    output           TXD,
    inout      [3:0] RAM_SIO,   // SIO3 is also the microSD DAT3/CS, held high when idle
    output           RAM_CE_B,
    output           RAM_CLK,
    output           FLASH_SCK,
    output           FLASH_SSB,
    output           FLASH_IO0,  // MOSI
    input            FLASH_IO1,  // MISO
    output           FLASH_IO2,  // WP#, held high (unused: single SPI)
    output           FLASH_IO3   // HOLD#, held high
`ifdef VIDEO
   ,output     [3:0] DVI_R,
    output     [3:0] DVI_G,
    output     [3:0] DVI_B,
    output           DVI_CLK,
    output           DVI_HS,
    output           DVI_VS,
    output           DVI_DE
`endif
);

    // Clock plan. The PLL makes the PSRAM engine clock, SPI_DIV times the CPU clock
    // (SCLK is half of it), and a counter divides it back down for the CPU; the
    // engine's req/ack handshake doesn't care about the ratio. The engine tops out
    // near 80 MHz. PLL: 12 * (DIVF+1) / 2^DIVQ, VCO 12 * (DIVF+1) in 533..1066.
    // VIDEO: engine 50.25 MHz (DIVF 66, DIVQ 4), pixel clock half of it, CPU the
    // same 25.125 MHz (same net as clk_pix, through its own SB_GB); the UART
    // divides that by 8 to 3.140625 Mbaud, which the FT2232H (12 MHz / n, n in
    // eighths) gets within 1.4% of.
    // Otherwise the CPU clock is CPU_MHZ (make CPU_MHZ=...): a multiple of 3, so
    // the UART divides it exactly to 3 Mbaud. 15 MHz: engine 60, SCLK 30. Above
    // 20 MHz the ratio is 2.
`ifdef VIDEO
`ifdef SLOW
    localparam SPI_DIV = 4;           // safe: CPU at 12.5625 MHz (the pixel clock stays 25.125)
`else
    localparam SPI_DIV = 2;           // turbo: CPU at 25.125 MHz
`endif
    localparam DIVQ = 4;
    localparam DIVF = 66;
    localparam UART_DIV = 16 / SPI_DIV;
`else
`ifndef CPU_MHZ
`define CPU_MHZ 15
`endif
    localparam CPU_MHZ = `CPU_MHZ;
    localparam SPI_DIV = CPU_MHZ > 20 ? 2 : 4;
    localparam SPI_MHZ = CPU_MHZ * SPI_DIV;
    localparam DIVQ = SPI_MHZ * 16 > 1066 ? 3 : 4;
    localparam DIVF = SPI_MHZ * (1 << DIVQ) / 12 - 1;       // 60 MHz: 79, VCO 960
    localparam UART_DIV = CPU_MHZ / 3;                      // 3 Mbaud
`endif
    wire clk_spi;
`ifdef BENCH
    assign clk_spi = CLK;
`else
    SB_PLL40_PAD #(
        .FEEDBACK_PATH("SIMPLE"),
        .DIVR(4'b0000),
        .DIVF(DIVF),
        .DIVQ(DIVQ),
        .FILTER_RANGE(3'b001)
    ) pll (
        .PACKAGEPIN(CLK),
        .PLLOUTGLOBAL(clk_spi),
        .RESETB(1'b1),
        .BYPASS(1'b0)
    );
`endif
    reg  [1:0] div = 2'd0;
    always @(posedge clk_spi) div <= div + 1;
    wire clk_cpu;
    SB_GB cpu_gb(.USER_SIGNAL_TO_GLOBAL_BUFFER(SPI_DIV == 2 ? div[0] : div[1]),
                 .GLOBAL_BUFFER_OUTPUT(clk_cpu));
`ifdef VIDEO
    wire clk_pix;
    SB_GB pix_gb(.USER_SIGNAL_TO_GLOBAL_BUFFER(div[0]), .GLOBAL_BUFFER_OUTPUT(clk_pix));
`endif

    Clockworks CW(.clock_in(clk_cpu), .clock_out(clk), .reset_ext(RESET), .resetn(resetn));
    wire resetn;
    wire clk;

    wire [31:0] mem_addr;
    wire [31:0] mem_rdata;
    wire        mem_rstrb;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;

    wire [29:0] mem_wordaddr = mem_addr[31:2];
    wire isPSRAM = mem_addr[23];
    wire isIO    = !mem_addr[23] &  mem_addr[22];
    wire isFB    = !mem_addr[23] & !mem_addr[22] &  mem_addr[21];
    wire isRAM   = !mem_addr[23] & !mem_addr[22] & !mem_addr[21];
    wire mem_wstrb = |mem_wmask;

    // Memory-mapped IO in IO page, 1-hot addressing in word address.
    localparam IO_LEDS_bit      = 0;  // W LEDS: bit 0 green, bit 4 red
    localparam IO_UART_DAT_bit  = 1;  // W data to send (8 bits)
    localparam IO_UART_CNTL_bit = 2;  // R status. bit 9: transmit FIFO full
    localparam IO_COUNTER_bit   = 3;  // R free-running clk counter
    localparam IO_MANDEL_CTRL   = 4;  // W start, R ready. Same map as the riscv/ SOC,
    localparam IO_MANDEL_CR     = 5;  //   so mandel.c runs on either
    localparam IO_MANDEL_CI     = 6;
    localparam IO_MANDEL_IT     = 7;  // R iterations left, W max iterations
    localparam IO_UART_RX_bit   = 8;  // R {valid, byte}; reading pops the 512-byte FIFO
    localparam IO_VIDEO_bit     = 9;  // W palette entry {index, 4'b0, 0xRGB} (bits 23:16, 11:0),
                                      //   R {game_front, frames[30:0]}
    localparam IO_GAME_bit      = 10; // W {front_req, game_mode} (bits 1, 0): low-detail
                                      //   double-buffered game view (see video.v)
    localparam IO_FLASH_ADDR_bit= 11; // W start_addr[23:0]: (re)start a streamed read.
    localparam IO_FLASH_DATA_bit= 12; //   R ready (bit 0) on ADDR, R next word (pops) on
    localparam IO_FLASH_END_bit = 13; //   DATA, W (any value) on END raises CS. See flash_spi.v.
    localparam IO_CLOCK_bit     = 14; // R CPU clock in Hz (turbo or SLOW build)

    wire [31:0] RAM_rdata;
    wire [31:0] counter;
    wire [31:0] psram_rdata;
    wire [31:0] fb_rdata;
    wire [31:0] frames;
    wire        game_front;
    wire        tx_full;
    wire        psram_rbusy, psram_wbusy;
    wire        flash_ready;
    wire [31:0] flash_rdata;

    wire [31:0] IO_rdata =
        mem_wordaddr[IO_UART_CNTL_bit] ? {22'b0, tx_full, 9'b0} :
        mem_wordaddr[IO_COUNTER_bit]   ? counter :
        mem_wordaddr[IO_UART_RX_bit]   ? {23'b0, rx_full, rx_data} :
        mem_wordaddr[IO_MANDEL_CTRL]   ? mandel_ready :
        mem_wordaddr[IO_MANDEL_IT]     ? mandel_iteration :
        mem_wordaddr[IO_VIDEO_bit]     ? {game_front, frames[30:0]} :
        mem_wordaddr[IO_FLASH_ADDR_bit]? {31'b0, flash_ready} :
        mem_wordaddr[IO_FLASH_DATA_bit]? flash_rdata :
        mem_wordaddr[IO_CLOCK_bit]     ? 50250000 / SPI_DIV
                                       : 32'b0;
    // Read data comes a cycle after the strobe, when the address may have moved
    // on (ProcessorPipe): the region and the IO value are latched on the strobe.
    // RAM and FB are both registered reads (1 cycle), like PSRAM on a cache hit.
    reg  [1:0]  rd_sel;   // 3 PSRAM, 2 RAM, 1 FB, 0 IO
    reg  [31:0] IO_q;
    always @(posedge clk) if (mem_rstrb) begin
        rd_sel <= isPSRAM ? 2'd3 : isRAM ? 2'd2 : isFB ? 2'd1 : 2'd0;
        IO_q   <= IO_rdata;
    end
    assign mem_rdata = rd_sel == 2'd3 ? psram_rdata :
                       rd_sel == 2'd2 ? RAM_rdata   :
                       rd_sel == 2'd1 ? fb_rdata    : IO_q;

    Memory RAM(
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_rdata(RAM_rdata),
        .mem_rstrb(isRAM & mem_rstrb),
        .mem_wdata(mem_wdata),
        .mem_wmask({4{isRAM}} & mem_wmask)
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
        .mem_rbusy(psram_rbusy),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_wbusy(psram_wbusy)
    );

    reg [4:0] LEDS = 5'b0;
    assign LEDG_N = !LEDS[0];
    assign LEDR_N = !LEDS[4];

    always @(posedge clk) begin
        if (isIO & mem_wstrb & mem_wordaddr[IO_LEDS_bit])
            LEDS <= mem_wdata;
    end

    // Mandelbrot accelerator (riscv.v)
    reg  signed [31:0] Cr, Ci;
    reg         [15:0] mandel_max_it = 31;
    wire        [15:0] mandel_iteration;
    wire               mandel_ready;

    Mandelbrot mb(.clk(clk), .resetn(resetn), .valid(isIO & mem_wstrb & mem_wordaddr[IO_MANDEL_CTRL]),
                  .ready(mandel_ready), .Cr(Cr), .Ci(Ci), .max_it(mandel_max_it), .iteration(mandel_iteration));

    always @(posedge clk) begin
        if (isIO & mem_wstrb & mem_wordaddr[IO_MANDEL_CR]) Cr <= mem_wdata;
        if (isIO & mem_wstrb & mem_wordaddr[IO_MANDEL_CI]) Ci <= mem_wdata;
        if (isIO & mem_wstrb & mem_wordaddr[IO_MANDEL_IT]) mandel_max_it <= mem_wdata;
    end

    wire uart_valid = isIO & mem_wstrb & mem_wordaddr[IO_UART_DAT_bit];

    UART_TX_FIFO #(.CLKS_PER_BIT(UART_DIV)) UART(
        .clk(clk), .resetn(resetn), .data(mem_wdata[7:0]), .valid(uart_valid), .full(tx_full), .tx(TXD)
    );

    free_cnt f_cnt1(.clk(clk), .resetn(resetn), .cnt(counter));

    // Receive FIFO: IO_q latches {valid, byte} on the load strobe, which also pops it.
    wire [7:0] rx_data;
    wire       rx_full;
    wire       rx_rd = isIO & mem_rstrb & mem_wordaddr[IO_UART_RX_bit];

    UART_RX_FIFO #(.CLKS_PER_BIT(UART_DIV)) UART_RX(.clk(clk), .rx(RXD), .pop(rx_rd), .q(rx_data), .q_valid(rx_full));

    FLASH_SPI flash(
        .clk(clk),
        .start(isIO & mem_wstrb & mem_wordaddr[IO_FLASH_ADDR_bit]),
        .start_addr(mem_wdata[23:0]),
        .pop(isIO & mem_rstrb & mem_wordaddr[IO_FLASH_DATA_bit]),
        .stop(isIO & mem_wstrb & mem_wordaddr[IO_FLASH_END_bit]),
        .rdata(flash_rdata),
        .ready(flash_ready),
        .sck(FLASH_SCK), .mosi(FLASH_IO0), .miso(FLASH_IO1), .ssb(FLASH_SSB),
        .io2(FLASH_IO2), .io3(FLASH_IO3)
    );

    PSRAM_BUS psram(
        .clk(clk),
        .sel(isPSRAM),
        .addr(mem_addr[22:0]),
        .rstrb(mem_rstrb),
        .wdata(mem_wdata),
        .wmask(mem_wmask),
        .rdata(psram_rdata),
        .rbusy(psram_rbusy),
        .wbusy(psram_wbusy),
        .clk_spi(clk_spi),
        .sio(RAM_SIO),
        .ce(RAM_CE_B),
        .sclk(RAM_CLK)
    );

`ifdef VIDEO
    VIDEO video(
        .clk(clk),
        .sel(isFB),
        .addr(mem_addr[15:0]),
        .rstrb(mem_rstrb),
        .wdata(mem_wdata),
        .wmask(mem_wmask),
        .rdata(fb_rdata),
        .pal_we(isIO & mem_wstrb & mem_wordaddr[IO_VIDEO_bit]),
        .game_we(isIO & mem_wstrb & mem_wordaddr[IO_GAME_bit]),
        .game_front(game_front),
        .frames(frames),
        .clk_pix(clk_pix),
        .dvi_r(DVI_R), .dvi_g(DVI_G), .dvi_b(DVI_B),
        .dvi_clk(DVI_CLK), .dvi_hs(DVI_HS), .dvi_vs(DVI_VS), .dvi_de(DVI_DE)
    );
`else
    assign fb_rdata   = 32'b0;
    assign frames     = 32'b0;
    assign game_front = 1'b0;
`endif

    `ifdef BENCH
    always @(posedge clk) begin
        if (uart_valid) begin
            $write("%c", mem_wdata[7:0]);
            $fflush(32'h8000_0001);
        end
    end
    `endif

endmodule
