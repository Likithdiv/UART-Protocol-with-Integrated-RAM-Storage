`timescale 1ns/1ps
module uart_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10
)(
    input [DATA_WIDTH-1:0] rx_data,
    input clk, rx_done, rst_n,
    input read_en,
    input [ADDR_WIDTH-1:0] read_addr,
    output reg [DATA_WIDTH-1:0] read_data,
    output reg [ADDR_WIDTH-1:0] ram_addr,
    output reg [DATA_WIDTH-1:0] ram_data_in,
    output reg ram_we
);
    reg [DATA_WIDTH-1:0] memory [0:(1 << ADDR_WIDTH)-1];
    reg [ADDR_WIDTH-1:0] write_ptr;

    // No array reset, allowing block RAM inference. Same-address read/write
    // returns old data. Only addresses written since reset are valid.
    always @(posedge clk) begin
        if (rst_n) begin
            if (rx_done) memory[write_ptr] <= rx_data;
            if (read_en) read_data <= memory[read_addr];
        end
        if (!rst_n) read_data <= 0;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            write_ptr <= 0;
            ram_addr <= 0;
            ram_data_in <= 0;
            ram_we <= 0;
        end else begin
            ram_we <= rx_done;
            if (rx_done) begin
                ram_addr <= write_ptr;
                ram_data_in <= rx_data;
                write_ptr <= write_ptr + 1'b1;
            end
        end
    end
endmodule
