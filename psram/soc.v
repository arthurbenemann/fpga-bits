`include "riscv.v"
`include "spi.v"

module SOC (
    input CLK,
    input RESET,
    output reg [4:0] LEDS,
    input RXD,
    output TXD,
    output RAM_SI,
    output RAM_CE_B,
    output RAM_CLK,
    input RAM_SO
);


  Clockworks CW (
      .clock_in(CLK),
      .clock_out(clk),
      .reset_ext(RESET),
      .resetn(resetn)
  );  // Fin 12Mhz,  Fout 16Mhz, delayed reset and POR
  wire resetn;
  wire clk;


  wire [31:0] RAM_rdata;
  wire [29:0] mem_wordaddr = mem_addr[31:2];
  wire isIO = mem_addr[22];
  wire isRAM = !isIO;
  wire mem_wstrb = |mem_wmask;

  wire [31:0] mem_addr;
  wire [31:0] mem_rdata;
  wire mem_rstrb;
  wire [31:0] mem_wdata;
  wire [3:0] mem_wmask;


  wire [31:0] IO_rdata = mem_wordaddr[IO_UART_CNTL_bit] ? {22'b0, !uart_ready, 9'b0} : 32'b0;
  assign mem_rdata = isRAM ? RAM_rdata : IO_rdata;


  Memory RAM (
      .clk(clk),
      .mem_addr(mem_addr),
      .mem_rdata(RAM_rdata),
      .mem_rstrb(isRAM & mem_rstrb),
      .mem_wdata(mem_wdata),
      .mem_wmask({4{isRAM}} & mem_wmask)
  );

  Processor CPU (
      .clk(clk),
      .resetn(resetn),
      .mem_addr(mem_addr),
      .mem_rdata(mem_rdata),
      .mem_rstrb(mem_rstrb),
      .mem_wdata(mem_wdata),
      .mem_wmask(mem_wmask)
  );

  // Memory-mapped IO in IO page, 1-hot addressing in word address.
  localparam IO_LEDS_bit = 0;
  localparam IO_UART_DAT_bit = 1;  // W data to send (8 bits) 
  localparam IO_UART_CNTL_bit = 2;  // R status. bit 9: busy sending


  always @(posedge clk) begin
    if (isIO & mem_wstrb & mem_wordaddr[IO_LEDS_bit]) begin
      LEDS <= mem_wdata;
    end
  end

  wire uart_valid = isIO & mem_wstrb & mem_wordaddr[IO_UART_DAT_bit];
  wire uart_ready;

  corescore_emitter_uart #(
      .clk_divider(48)  // Fin=12Mhz, baud =12Mhz/24 = 250kbaud
  ) UART (
      .i_clk(clk),
      .i_rst(resetn),
      .i_data(mem_wdata[7:0]),
      .i_valid(uart_valid),
      .o_ready(uart_ready),
      .o_uart_tx(TXD)
  );

  reg miso = 0;
  wire mosi, sclk;

  reg strb = 0;
  reg [7:0] transmit = 8'b1100_1010;
  wire [7:0] received;
  wire valid;

  SPI spi_psram (
      .clk(CLK),

      .miso(RAM_SO),
      .mosi(RAM_SI),
      //.ce(RAM_CE_B),
      .sclk(RAM_CLK),

      .strb(strb),
      .transmit(transmit),
      .received(received),
      .valid(valid)
  );



  // DEBUG terminal
`ifdef BENCH
  always @(posedge clk) begin
    if (uart_valid) begin
      $write("%c", mem_wdata[7:0]);
      $fflush(32'h8000_0001);
    end
  end
`endif

endmodule
