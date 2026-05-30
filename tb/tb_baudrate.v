`timescale 1ns/1ps
module tb_brg ();

    // Testbench Variables  
    parameter clk_freq = 50_000_000;
    parameter baud_rate = 115200;

    reg clk = 0;
    reg rst_n;

    wire baud_tick;

    // DUT Instance
    baudrate_gen #(
        .CLK_FREQ(clk_freq),
        .BAUD_RATE(baud_rate)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick)
    );

    // Clock Signals
    always begin
        #10;
        clk = ~clk;
    end

    // Stimulus
    initial begin
        rst_n = 0; // set reset

        #100;
        rst_n = 1;  // release reset

        // Run long enough to observe baud ticks
        repeat (1500) @(posedge clk);

        $stop;
    end

endmodule