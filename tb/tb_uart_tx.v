`timescale 1ns/1ps

module tb_uart_tx ();

// Testbench Parameters
    parameter clk_freq = 50_000_000;
    parameter baud_rate = 115200;

// Testbench Variables
    reg clk = 0;
    reg rst_n;
    reg [7:0] data_in;
    reg tx_start;


    wire baud_tick;
    wire tx_out;

// Baud Generator
    baudrate_gen #(
        .CLK_FREQ(clk_freq),
        .BAUD_RATE(baud_rate)
    ) BRG1 (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick)
    );

// Transmitter
    transmitter TX0 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .tx_start(tx_start),
        .baud_tick(baud_tick),
        .tx_out(tx_out)
    );

// 50MHz Clk
    always  begin
        #10 clk = ~clk;
    end

// Stimulus
initial begin
    rst_n = 0;  // set reset
    tx_start = 1'b0;
    data_in = 8'h00;
    
    #100;
    rst_n =1; // release reset

    data_in = 8'h41;
    tx_start = 1'b1;
    @(posedge clk); // hold for one clock cycle;
    tx_start = 1'b0;

    repeat(4500) @ (posedge clk);

    $stop;
end
endmodule