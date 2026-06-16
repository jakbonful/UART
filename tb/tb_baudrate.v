`timescale 1ns/1ps

module tb_baudrate_gen;

    // DUT parameters
    parameter CLK_FREQ  = 50_000_000;
    parameter BAUD_RATE = 115200;

    localparam CLK_PERIOD = 20; // 50MHz = 20ns
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg clk;
    reg rst_n;
    wire baud_tick;

    // DUT
    baudrate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) BRG (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick)
    );

    // Clock
    always #(CLK_PERIOD/2) clk = ~clk;

    // Tracking
    integer cycle_count;
    integer last_tick_cycle;
    integer measured_gap;

    integer tick_count;
    integer error_flag;

    initial begin
        clk = 0;
        rst_n = 0;

        cycle_count = 0;
        last_tick_cycle = 0;
        tick_count = 0;
        error_flag = 0;

        // reset
        #(10 * CLK_PERIOD);
        rst_n = 1;

        // run simulation
        repeat (20000) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (baud_tick) begin
                tick_count = tick_count + 1;

                measured_gap = cycle_count - last_tick_cycle;

                // Check correctness
                if (tick_count > 1) begin
                    if (measured_gap != CLKS_PER_BIT) begin
                        error_flag = 1;
                    end
                end

                last_tick_cycle = cycle_count;
            end
        end

        // FINAL CHECK ONLY (no waveform noise)
        if (error_flag == 0 && tick_count > 0) begin
            $display("PASS");
        end else begin
            $display("FAIL");
        end

        $stop;
    end

endmodule