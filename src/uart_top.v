`timescale 1ns/1ps
module uart_top #(
    parameter BAUD_DIV = 10416,
    parameter RAM_ADDR_WIDTH = 10
) (
    input clk, rst_n,
    input tx_start,
    input [7:0] tx_byte,
    output tx_line,
    output tx_busy,
    input rx_line,
    output [7:0] rx_byte,
    output rx_done,
    output framing_error,
    input ram_read_en,
    input [RAM_ADDR_WIDTH-1:0] ram_read_addr,
    output [7:0] ram_read_data,
    output [RAM_ADDR_WIDTH-1:0] ram_addr,
    output [7:0] ram_data_in,
    output ram_we
);

    uart_tx #(.TICKS_PER_BIT(BAUD_DIV)) transmitter (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_byte),
        .tx(tx_line),
        .tx_busy(tx_busy)
    );

    uart_rx #(.TICKS_PER_BIT(BAUD_DIV)) receiver (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx_line),
        .rx_data(rx_byte),
        .rx_done(rx_done),
        .framing_error(framing_error)
    );
    uart_ram #(.DATA_WIDTH(8), .ADDR_WIDTH(RAM_ADDR_WIDTH)) memory_unit (
        .clk(clk), .rst_n(rst_n), .rx_data(rx_byte), .rx_done(rx_done),
        .read_en(ram_read_en), .read_addr(ram_read_addr),
        .read_data(ram_read_data), .ram_addr(ram_addr),
        .ram_data_in(ram_data_in), .ram_we(ram_we)
    );
endmodule
