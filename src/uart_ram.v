module uart_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10
)(
    input [7:0] rx_data,
    input clk, rx_done, rst_n,
    output reg [ADDR_WIDTH-1:0] ram_addr,
    output reg [DATA_WIDTH-1:0] ram_data_in,
    output reg ram_we
);

    always @(posedge clk) begin
        if (!rst_n) begin
            ram_addr    <= 0;
            ram_data_in <= 0;
            ram_we      <= 0;
        end 
        else if (rx_done) begin
            ram_data_in <= rx_data;
            ram_we      <= 1'b1;
            
        end 
        else if (ram_we) begin
            ram_addr    <= ram_addr + 1'b1; 
            ram_we      <= 1'b0;            
        end
    end

endmodule
