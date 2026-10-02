`timescale 1ns/1ps
module uart_ram_tb;
    reg clk=0, rst_n=0, rx_done=0, read_en=0;
    reg [7:0] rx_data=0;
    reg [1:0] read_addr=0;
    wire [7:0] read_data, ram_data_in;
    wire [1:0] ram_addr;
    wire ram_we;
    integer i;
    uart_ram #(.ADDR_WIDTH(2)) dut (
        .clk(clk), .rst_n(rst_n), .rx_done(rx_done), .rx_data(rx_data),
        .read_en(read_en), .read_addr(read_addr), .read_data(read_data),
        .ram_addr(ram_addr), .ram_data_in(ram_data_in), .ram_we(ram_we)
    );
    always #5 clk=~clk;
    initial begin #2000; $fatal(1,"RAM timeout"); end
    initial begin
        repeat(2) @(negedge clk); rst_n=1;
        // Consecutive clock-cycle writes must advance the address every cycle.
        for(i=0;i<6;i=i+1) begin
            @(negedge clk); rx_done=1; rx_data=8'h40+i;
            @(posedge clk); #1;
            if (!ram_we || ram_addr !== (i%4) || ram_data_in !== rx_data) $fatal(1,"Write %0d failed",i);
        end
        @(negedge clk); rx_done=0;
        for(i=0;i<4;i=i+1) begin
            @(negedge clk); read_en=1; read_addr=i;
            @(posedge clk); #1;
            if (read_data !== ((i<2) ? 8'h44+i : 8'h40+i)) $fatal(1,"Read %0d failed",i);
        end
        // Next write is address 2; collision must read its old value (0x42).
        @(negedge clk); read_addr=2; rx_done=1; rx_data=8'hEE;
        @(posedge clk); #1;
        if (read_data !== 8'h42) $fatal(1,"Read-during-write semantics failed");
        @(negedge clk); rx_done=0;
        @(posedge clk); #1;
        if (read_data !== 8'hEE) $fatal(1,"Collision write not retained");
        $display("PASS uart_ram_tb: consecutive writes, wrap, readback, read/write collision");
        $finish;
    end
endmodule
