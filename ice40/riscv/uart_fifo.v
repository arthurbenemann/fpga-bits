// 8N1 UART transmitter behind a 512-byte FIFO in one EBR: the CPU queues output
// and goes back to work while the UART drains it. Write `data` with `valid` only
// while !full; tx_q holds the next byte for the UART.
module UART_TX_FIFO #(
    parameter CLKS_PER_BIT = 4
) (
    input        clk,
    input        resetn,
    input  [7:0] data,
    input        valid,
    output       full,
    output       tx
);
    reg  [7:0] fifo [0:511];
    reg  [8:0] wr = 0, rd = 0;
    reg  [7:0] q;
    reg        q_valid = 1'b0;
    wire       ready;
    wire       take = q_valid && ready;                  // the UART takes q
    wire       load = wr != rd && (!q_valid || take);    // refill q
    assign     full = wr + 9'd1 == rd;

    always @(posedge clk) begin
        if (valid && !full) begin
            fifo[wr] <= data;
            wr <= wr + 1;
        end
        if (load) begin
            q  <= fifo[rd];
            rd <= rd + 1;
        end
        if (load) q_valid <= 1'b1;
        else if (take) q_valid <= 1'b0;
    end

    corescore_emitter_uart #(.clk_divider(CLKS_PER_BIT)) UART(
        .i_clk(clk), .i_rst(resetn), .i_data(q), .i_valid(q_valid), .o_ready(ready), .o_uart_tx(tx)
    );
endmodule

// 8N1 UART receiver into a 512-byte FIFO in one EBR, so bytes arriving while the
// CPU is busy wait. q holds the oldest byte while q_valid; `pop` takes it.
module UART_RX_FIFO #(
    parameter CLKS_PER_BIT = 4
) (
    input            clk,
    input            rx,
    input            pop,
    output reg [7:0] q,
    output reg       q_valid = 1'b0
);
    reg  [7:0] fifo [0:511];
    reg  [8:0] wr = 0, rd = 0;
    wire [7:0] data;
    wire       valid;
    wire       load = wr != rd && (!q_valid || pop);     // refill q

    always @(posedge clk) begin
        if (valid && wr + 9'd1 != rd) begin             // full: drop the byte
            fifo[wr] <= data;
            wr <= wr + 1;
        end
        if (load) begin
            q  <= fifo[rd];
            rd <= rd + 1;
        end
        if (load) q_valid <= 1'b1;
        else if (pop) q_valid <= 1'b0;
    end

    UART_RX #(.CLKS_PER_BIT(CLKS_PER_BIT)) RX(.clk(clk), .rx(rx), .data(data), .valid(valid));
endmodule
