`timescale 1ns/1ps
module uart_rx #(parameter TICKS_PER_BIT = 10416) (
    input clk, rst_n, rx,
    output reg [7:0] rx_data,
    output reg rx_done,
    output reg framing_error
);
    localparam IDLE=0, START=1, DATA=2, STOP=3, RECOVER=4;
    localparam TIMER_WIDTH = (TICKS_PER_BIT > 1) ? $clog2(TICKS_PER_BIT) : 1;
    localparam [TIMER_WIDTH-1:0] LAST_TICK = TICKS_PER_BIT - 1;
    localparam [TIMER_WIDTH-1:0] HALF_TICK = TICKS_PER_BIT / 2 - 1;
    reg [2:0] state;
    reg [TIMER_WIDTH-1:0] timer;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;
    (* ASYNC_REG = "TRUE" *) reg rx_sync1, rx_sync2;

    // synthesis translate_off
    initial if (TICKS_PER_BIT < 8) $fatal(1, "TICKS_PER_BIT must be at least 8");
    // synthesis translate_on

    // Only the second synchronizer stage feeds the receiver state machine.
    always @(posedge clk) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            rx_done <= 0;
            framing_error <= 0;
            rx_data <= 0;
            timer <= 0;
            bit_idx <= 0;
            shift_reg <= 0;
        end else begin
            rx_done <= 0;
            framing_error <= 0;
            case (state)
                IDLE: begin
                    timer <= 0;
                    bit_idx <= 0;
                    if (!rx_sync2) state <= START;
                end
                START: begin
                    if (timer == HALF_TICK) begin
                        timer <= 0;
                        if (!rx_sync2) state <= DATA;
                        else state <= IDLE;
                    end else timer <= timer + 1'b1;
                end
                DATA: begin
                    if (timer < LAST_TICK) timer <= timer + 1'b1;
                    else begin
                        timer <= 0;
                        shift_reg[bit_idx] <= rx_sync2;
                        if (bit_idx < 7) bit_idx <= bit_idx + 1'b1;
                        else state <= STOP;
                    end
                end
                STOP: begin
                    if (timer < LAST_TICK) timer <= timer + 1'b1;
                    else begin
                        timer <= 0;
                        if (rx_sync2) begin
                            rx_data <= shift_reg;
                            rx_done <= 1;
                            state <= IDLE;
                        end else begin
                            framing_error <= 1;
                            state <= RECOVER;
                        end
                    end
                end
                // Wait for release of a held-low line after a framing error.
                RECOVER: if (rx_sync2) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
