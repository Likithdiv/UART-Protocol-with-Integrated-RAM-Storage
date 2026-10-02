`timescale 1ns/1ps
module uart_top_tb;
    parameter DIV = 100;
    reg clk=0, rst_n=0, tx_start=0;
    reg [7:0] tx_byte=0;
    wire tx_line, tx_busy, rx_done, framing_error;
    wire [7:0] rx_byte, ram_read_data, ram_data_in;
    wire [1:0] ram_addr;
    wire ram_we;
    reg loopback=1, external_rx=1, ram_read_en=0;
    reg [1:0] ram_read_addr=0;
    reg [7:0] expected [0:511];
    reg [7:0] stored [0:3];
    reg [7:0] last_valid_byte;
    integer queued=0, received=0, written=0, errors=0;
    integer i, before_count;
    integer rx_ticks=DIV;
    uart_top #(.BAUD_DIV(DIV), .RAM_ADDR_WIDTH(2)) dut (
        .clk(clk), .rst_n(rst_n), .tx_start(tx_start), .tx_byte(tx_byte),
        .tx_line(tx_line), .tx_busy(tx_busy),
        .rx_line(loopback ? tx_line : external_rx),
        .rx_byte(rx_byte), .rx_done(rx_done), .framing_error(framing_error),
        .ram_read_en(ram_read_en), .ram_read_addr(ram_read_addr),
        .ram_read_data(ram_read_data), .ram_addr(ram_addr),
        .ram_data_in(ram_data_in), .ram_we(ram_we)
    );
    always #5 clk=~clk;
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("uart_top.vcd"); $dumpvars(0, uart_top_tb);
        end
        #(DIV * 10 * 6000);
        $fatal(1, "Timeout: received=%0d queued=%0d", received, queued);
    end
    // Observe after nonblocking assignments have settled.
    always @(posedge clk) begin
        #1;
        if (rst_n) begin
            if (rx_done) begin
                if (received >= queued || rx_byte !== expected[received])
                    $fatal(1, "RX mismatch at byte %0d: %h", received, rx_byte);
                received=received+1;
            end
            if (framing_error) errors=errors+1;
            if (ram_we) begin
                if (written >= queued || ram_data_in !== expected[written] || ram_addr !== (written % 4))
                    $fatal(1, "RAM write mismatch at byte %0d", written);
                stored[written % 4]=expected[written];
                written=written+1;
            end
        end
    end
    task queue_byte;
        input [7:0] value;
        begin expected[queued]=value; queued=queued+1; end
    endtask
    task read_check;
        input [1:0] address;
        begin
            @(negedge clk); ram_read_addr=address; ram_read_en=1;
            @(posedge clk); #2;
            if (ram_read_data !== stored[address]) $fatal(1, "RAM read mismatch at %0d", address);
            @(negedge clk); ram_read_en=0;
        end
    endtask
    task send_tx;
        input [7:0] value;
        integer bit_no, tick_no;
        reg expected_bit;
        begin
            if (loopback) queue_byte(value);
            wait(!tx_busy);
            @(negedge clk); tx_byte=value; tx_start=1;
            fork
                begin
                    @(negedge clk); tx_start=0; tx_byte=~value;
                    // Requests while busy must be ignored; latched data stays intact.
                    repeat(2) @(negedge clk); tx_start=1;
                    @(negedge clk); tx_start=0;
                end
                begin
                    @(negedge tx_line);
                    for(bit_no=-1;bit_no<9;bit_no=bit_no+1) begin
                        if (bit_no == -1) expected_bit=0;
                        else if (bit_no == 8) expected_bit=1;
                        else expected_bit=value[bit_no];
                        for(tick_no=0;tick_no<DIV;tick_no=tick_no+1) begin
                            @(negedge clk);
                            if (tx_line !== expected_bit)
                                $fatal(1, "TX bit %0d duration/value mismatch at tick %0d", bit_no,tick_no);
                        end
                    end
                end
            join
            wait(!tx_busy);
            wait(written == queued);
        end
    endtask
    // Independent serial source: no dependency on transmitter timing/state.
    task send_rx;
        input [7:0] value;
        input good_stop;
        integer bit_no;
        begin
            if (good_stop) queue_byte(value);
            @(negedge clk); external_rx=0;
            repeat(rx_ticks) @(negedge clk);
            for(bit_no=0;bit_no<8;bit_no=bit_no+1) begin
                external_rx=value[bit_no];
                repeat(rx_ticks) @(negedge clk);
            end
            external_rx=good_stop;
            repeat(rx_ticks) @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        @(posedge clk); #2;
        if (rx_byte !== 0 || rx_done !== 0 || tx_busy !== 0 || tx_line !== 1 || framing_error !== 0 || ram_read_data !== 0)
            $fatal(1, "Reset outputs incorrect");
        send_tx(8'hA5); send_tx(8'h3C); send_tx(8'h00); send_tx(8'hFF);
        send_tx(8'h55); send_tx(8'hAA);
        for(i=0;i<4;i=i+1) read_check(i[1:0]);
        // RX back-to-back frames and write pointer wraparound.
        @(negedge clk); loopback=0;
        send_rx(8'h12,1); send_rx(8'h34,1); send_rx(8'h56,1); send_rx(8'h78,1);
        if (DIV == 100) begin
            for(i=0;i<256;i=i+1) send_rx(i[7:0],1);
        end
        if (DIV >= 50) begin
            rx_ticks=DIV-DIV/50; send_rx(8'h96,1);
            @(negedge clk); external_rx=1; repeat(DIV) @(negedge clk);
            rx_ticks=DIV+DIV/50; send_rx(8'h69,1);
            rx_ticks=DIV;
        end
        wait(written == queued);
        for(i=0;i<4;i=i+1) read_check(i[1:0]);
        fork
            send_tx(8'hD2);
            send_rx(8'h2D,1);
        join
        before_count=received;
        last_valid_byte=rx_byte;
        send_rx(8'hE7,0);
        // Hold low for multiple frames: one error, no repeated bytes.
        repeat(DIV*25) @(negedge clk);
        if (received != before_count || errors != 1 || written != queued || rx_byte !== last_valid_byte)
            $fatal(1, "Malformed stop/break was not rejected");
        external_rx=1; repeat(DIV) @(negedge clk);
        // Short glitch must not become a start bit.
        external_rx=0; repeat(DIV/4) @(negedge clk); external_rx=1;
        repeat(DIV*12) @(negedge clk);
        if (received != before_count || errors != 1) $fatal(1, "False start accepted");
        send_rx(8'hC9,1); wait(written == queued);
        // Abort simultaneous TX and RX activity with synchronous reset.
        @(negedge clk); tx_byte=8'h81; tx_start=1; external_rx=0;
        @(negedge clk); tx_start=0;
        repeat(DIV*2) @(negedge clk);
        rst_n=0; external_rx=1;
        repeat(4) @(negedge clk);
        queued=0; received=0; written=0; errors=0;
        rst_n=1; loopback=1;
        @(posedge clk); #2;
        if (rx_byte !== 0 || rx_done !== 0 || tx_busy !== 0 || tx_line !== 1 || framing_error !== 0)
            $fatal(1, "Mid-frame reset failed");
        send_tx(8'h6D); read_check(0);
        $display("PASS uart_top_tb DIV=%0d: TX, RX, RAM, wrap, framing, break, false start, reset", DIV);
        $finish;
    end
endmodule
