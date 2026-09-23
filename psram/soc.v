// RISC-V core from ../riscv with the PSRAM engine as a memory-mapped peripheral.
// Build with -I../riscv; riscv.v also defines its own SOC/Mandelbrot tops, which
// go unused here.
`include "riscv.v"
`include "psram_spi.v"

module PSRAM_SOC (
    input            CLK,
    input            RESET,
    output reg [4:0] LEDS,
    input            RXD,
    output           TXD,
    output           RAM_SI,
    output           RAM_CE_B,
    output           RAM_CLK,
    input            RAM_SO,
    output           SD_CS      // microSD CS shares the bus
);
    assign SD_CS = 1'b1;        // keep the card deselected

    Clockworks CW(.clock_in(CLK), .clock_out(clk), .reset_ext(RESET), .resetn(resetn)); // 12 MHz, no PLL
    wire resetn;
    wire clk;

    wire [31:0] mem_addr;
    wire [31:0] mem_rdata;
    wire        mem_rstrb;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;

    wire [29:0] mem_wordaddr = mem_addr[31:2];
    wire isIO  = mem_addr[22];
    wire isRAM = !isIO;
    wire mem_wstrb = |mem_wmask;

    // Memory-mapped IO in IO page, 1-hot addressing in word address.
    localparam IO_LEDS_bit      = 0;  // W five leds
    localparam IO_UART_DAT_bit  = 1;  // W data to send (8 bits)
    localparam IO_UART_CNTL_bit = 2;  // R status. bit 9: busy sending
    localparam IO_COUNTER_bit   = 3;  // R free-running clk counter
    localparam IO_PSRAM_CMD_bit = 4;  // W {cmd[7:0], addr[23:0]} starts a transfer; R bit 0: busy
    localparam IO_PSRAM_DAT_bit = 5;  // W data for next write; R data from last transfer

    wire [31:0] RAM_rdata;
    wire [31:0] counter;
    wire        uart_ready;
    wire [31:0] psram_rdata;
    wire        psram_busy;

    wire [31:0] IO_rdata =
        mem_wordaddr[IO_UART_CNTL_bit] ? {22'b0, !uart_ready, 9'b0} :
        mem_wordaddr[IO_COUNTER_bit]   ? counter :
        mem_wordaddr[IO_PSRAM_CMD_bit] ? {31'b0, psram_busy} :
        mem_wordaddr[IO_PSRAM_DAT_bit] ? psram_rdata
                                       : 32'b0;
    assign mem_rdata = isRAM ? RAM_rdata : IO_rdata;

    Memory RAM(
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_rdata(RAM_rdata),
        .mem_rstrb(isRAM & mem_rstrb),
        .mem_wdata(mem_wdata),
        .mem_wmask({4{isRAM}} & mem_wmask)
    );

    Processor CPU(
        .clk(clk),
        .resetn(resetn),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask)
    );

    always @(posedge clk) begin
        if (isIO & mem_wstrb & mem_wordaddr[IO_LEDS_bit])
            LEDS <= mem_wdata;
    end

    wire uart_valid = isIO & mem_wstrb & mem_wordaddr[IO_UART_DAT_bit];

    corescore_emitter_uart #(
        .clk_divider(12)     // 12 MHz / 12 = 1 Mbaud
    ) UART(
        .i_clk(clk),
        .i_rst(resetn),
        .i_data(mem_wdata[7:0]),
        .i_valid(uart_valid),
        .o_ready(uart_ready),
        .o_uart_tx(TXD)
    );

    free_cnt f_cnt1(.clk(clk), .resetn(resetn), .cnt(counter));

    reg [31:0] psram_wdata;
    always @(posedge clk) begin
        if (isIO & mem_wstrb & mem_wordaddr[IO_PSRAM_DAT_bit])
            psram_wdata <= mem_wdata;
    end

    PSRAM_SPI psram(
        .clk(clk),
        .start(isIO & mem_wstrb & mem_wordaddr[IO_PSRAM_CMD_bit]),
        .cmd(mem_wdata[31:24]),
        .addr(mem_wdata[23:0]),
        .wdata(psram_wdata),
        .rdata(psram_rdata),
        .busy(psram_busy),
        .miso(RAM_SO),
        .mosi(RAM_SI),
        .ce(RAM_CE_B),
        .sclk(RAM_CLK)
    );

    `ifdef BENCH
    always @(posedge clk) begin
        if (uart_valid) begin
            $write("%c", mem_wdata[7:0]);
            $fflush(32'h8000_0001);
        end
    end
    `endif

endmodule
