
`timescale 1ns/1ps
module uart_tx #(parameter TICKS_PER_BIT = 10416) (
    input clk, tx_start, rst_n,  // Active-low synchronous reset
    input [7:0] tx_data, //inputs transmitter data
    output reg tx, tx_busy //used to indicate if wire is in use and if tx is ready to use
);
    localparam IDLE=0, START=1, DATA=2, STOP=3; //conditions of case
    reg [1:0] state; //used to control case flow
    localparam TIMER_WIDTH = (TICKS_PER_BIT > 1) ? $clog2(TICKS_PER_BIT) : 1;
    localparam [TIMER_WIDTH-1:0] LAST_TICK = TICKS_PER_BIT - 1;
    reg [TIMER_WIDTH-1:0] timer;
    reg [2:0] bit_idx;
    reg [7:0] data_shifter; //used to shift data from input to wire

    // synthesis translate_off
    initial if (TICKS_PER_BIT < 8) $fatal(1, "TICKS_PER_BIT must be at least 8");
    // synthesis translate_on

    always @(posedge clk) begin
        if(!rst_n) begin //rst is an input and if rst is triggered it will completely reset the system back to idle and all values are set to 0
            state <= IDLE;
            tx <= 1;
            tx_busy <= 0;
            timer <= 0;
            bit_idx <= 0;
            data_shifter <= 0;
        end
        else begin
            case(state)
                IDLE: begin //initializes all values to base and gets the system ready for transmition
                    tx <= 1;
                    tx_busy <= 0;
                    bit_idx <= 0;
                    if(tx_start) begin
                        data_shifter <= tx_data; //shifts data from input to wire
                        tx_busy <= 1; //indicates tx wire is in use
                        state <= START;
                        timer <= 0;
                    end
                end
                START: begin
                    tx <= 0;//pulling line to low to start the process
                    if(timer < LAST_TICK)
                        timer <= timer + 1;
                    else begin
                        timer <= 0;
                        state <= DATA;
                    end
                end
                DATA: begin //parallel data to serial conversion
                    tx <= data_shifter[bit_idx]; //data is sent bit by bit using tx wire and we navigate the data using a pointer which is bit_idx here
                    if(timer < LAST_TICK)
                        timer <= timer + 1;
                    else begin
                        timer <= 0;
                        if(bit_idx < 7)
                            bit_idx <= bit_idx + 1;
                        else
                            state <= STOP;
                    end
                end
                STOP: begin
                    tx <= 1; //pull line high to stop
                    tx_busy <=1;
                    if(timer < LAST_TICK)
                        timer <= timer + 1;
                    else begin
                        state <= IDLE;
                        timer <= 0;
                        tx_busy<=0;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
