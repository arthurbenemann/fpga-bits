// RISC-V core from ../riscv with the PSRAM mapped into its address space.
//   0x000000-0x3FFFFF  BRAM (6 KB populated)
//   0x400000-0x7FFFFF  IO page
//   0x800000-0xFFFFFF  PSRAM, 8 MB
// Build with -I../riscv; riscv.v also defines its own SOC/Mandelbrot tops, which
// go unused here.
`include "riscv.v"
`include "psram_spi.v"
`include "psram_bus.v"

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

    // Port A passes the 12 MHz pad clock through for the CPU; port B is the
    // PLL output for the PSRAM engine: 12 * (79+1) / 2^4 = 60 MHz (SCLK 30 MHz).
    wire clk_12, clk_spi;
`ifdef BENCH
    assign clk_12 = CLK;
    assign clk_spi = CLK;
`else
    SB_PLL40_2_PAD #(
        .FEEDBACK_PATH("SIMPLE"),
        .PLLOUT_SELECT_PORTB("GENCLK"),
        .DIVR(4'b0000),
        .DIVF(7'b1001111),
        .DIVQ(3'b100),
        .FILTER_RANGE(3'b001)
    ) pll (
        .PACKAGEPIN(CLK),
        .PLLOUTGLOBALA(clk_12),
        .PLLOUTGLOBALB(clk_spi),
        .RESETB(1'b1),
        .BYPASS(1'b0)
    );
`endif

    Clockworks CW(.clock_in(clk_12), .clock_out(clk), .reset_ext(RESET), .resetn(resetn));
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
    wire isRAM   = !mem_addr[23] & !mem_addr[22];
    wire mem_wstrb = |mem_wmask;

    // Memory-mapped IO in IO page, 1-hot addressing in word address.
    localparam IO_LEDS_bit      = 0;  // W five leds
    localparam IO_UART_DAT_bit  = 1;  // W data to send (8 bits)
    localparam IO_UART_CNTL_bit = 2;  // R status. bit 9: busy sending
    localparam IO_COUNTER_bit   = 3;  // R free-running clk counter
    localparam IO_UART_RX_bit   = 4;  // R {valid, byte}; reading clears valid

    wire [31:0] RAM_rdata;
    wire [31:0] counter;
    wire        uart_ready;
    wire [31:0] psram_rdata;
    wire        psram_rbusy, psram_wbusy;

    wire [31:0] IO_rdata =
        mem_wordaddr[IO_UART_CNTL_bit] ? {22'b0, !uart_ready, 9'b0} :
        mem_wordaddr[IO_COUNTER_bit]   ? counter :
        mem_wordaddr[IO_UART_RX_bit]   ? {23'b0, rx_read}
                                       : 32'b0;
    assign mem_rdata = isPSRAM ? psram_rdata :
                       isRAM   ? RAM_rdata   : IO_rdata;

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
        .mem_rbusy(psram_rbusy),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_wbusy(psram_wbusy)
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

    // One-byte receive buffer. The CPU samples IO data a cycle after the load
    // strobe, so the register value is latched on the strobe, which also clears it.
    wire [7:0] rx_data;
    wire       rx_valid;
    reg        rx_full = 1'b0;
    reg  [8:0] rx_read;
    wire       rx_rd = isIO & mem_rstrb & mem_wordaddr[IO_UART_RX_bit];

    UART_RX #(.CLKS_PER_BIT(12)) UART_RX(.clk(clk), .rx(RXD), .data(rx_data), .valid(rx_valid));

    always @(posedge clk) begin
        if (rx_rd) rx_read <= {rx_full, rx_data};
        if (rx_valid) rx_full <= 1'b1;
        else if (rx_rd) rx_full <= 1'b0;
    end

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
