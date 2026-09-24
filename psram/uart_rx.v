// 8N1 UART receiver. Samples the middle of each bit; `valid` pulses for one
// clk with `data` when a byte with a good stop bit arrives (data holds until
// the next byte).
module UART_RX #(
    parameter CLKS_PER_BIT = 12
) (
    input            clk,
    input            rx,
    output reg [7:0] data,
    output reg       valid = 1'b0
);
    reg [1:0] rx_s = 2'b11;
    reg       busy = 1'b0;
    reg [3:0] bit_idx;
    reg [$clog2(CLKS_PER_BIT * 3 / 2 + 1)-1:0] cnt;
    reg [7:0] shift;

    always @(posedge clk) begin
        rx_s  <= {rx_s[0], rx};
        valid <= 1'b0;
        if (!busy) begin
            if (!rx_s[1]) begin                     // start bit: wait 1.5 bits to mid bit 0
                busy    <= 1'b1;
                bit_idx <= 0;
                cnt     <= CLKS_PER_BIT * 3 / 2 - 1;
            end
        end else if (cnt != 0) begin
            cnt <= cnt - 1;
        end else if (bit_idx != 8) begin
            shift   <= {rx_s[1], shift[7:1]};       // LSB first
            bit_idx <= bit_idx + 1;
            cnt     <= CLKS_PER_BIT - 1;
        end else begin                              // mid stop bit
            busy <= 1'b0;
            if (rx_s[1]) begin
                data  <= shift;
                valid <= 1'b1;
            end
        end
    end
endmodule
