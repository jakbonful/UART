`timescale 1ns/1ps

module tb_uart_rx ();

    // Testbench Parameters
    parameter clk_freq = 50_000_000;
    parameter baud_rate = 16 * 115200;

    // Testbench Variables
    reg clk = 0;
    reg rst_n;
    reg rx_in;

    // Outputs
    wire [7:0] data_out;
    wire rx_valid;
    wire over_sample_baud_tick;



// Baud Generator
    baudrate_gen #(
        .CLK_FREQ(clk_freq),
        .BAUD_RATE(baud_rate)
    ) BRG2 (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(over_sample_baud_tick)
    );

// Receiver
    receiver REC1 (
        .clk(clk),
        .rst_n(rst_n),
        .over_sample_baud_tick(over_sample_baud_tick),
        .rx_in(rx_in),
        .data_out(data_out),
        .rx_valid(rx_valid)
    );

// 50 MHz Clock
    always begin
        #10 clk = ~clk;
    end



// Stimulus
    initial begin
        rst_n = 0;
        rx_in = 1;

        #100;
        rst_n = 1;

        // Start bit
        rx_in = 0;
        repeat(16) @(posedge over_sample_baud_tick);

        // D0
        rx_in = 1;
        repeat(16) @(posedge over_sample_baud_tick);

        // D1
        rx_in = 0;
        repeat(16) @(posedge over_sample_baud_tick);

        // D2
        rx_in = 0;
        repeat(16) @(posedge over_sample_baud_tick);

        // D3
        rx_in = 0;
        repeat(16) @(posedge over_sample_baud_tick);

        // D4
        rx_in = 0;
        repeat(16) @(posedge over_sample_baud_tick);

        // D5
        rx_in = 0;
        repeat(16) @(posedge over_sample_baud_tick);

        // D6
        rx_in = 1;
        repeat(16) @(posedge over_sample_baud_tick);

        // D7
        rx_in = 0;
        repeat(16) @(posedge over_sample_baud_tick);

        
        // Stop bit
        rx_in = 1;
        repeat(16) @(posedge over_sample_baud_tick);

        // Wait for rx_valid to pulse
        repeat(50) @(posedge clk);

        if (data_out == 8'h41)
            $display("PASS: received 0x%h", data_out);
        else
            $display("FAIL: expected 0x41, got 0x%h", data_out);

        $stop;

    end

endmodule