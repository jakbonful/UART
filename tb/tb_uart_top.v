`timescale 1ns/1ps

module tb_uart_top;

    reg        clk;
    reg        rst_n;
    reg  [7:0] data_in;
    reg        start_signal;

    wire       rx_valid;
    wire [7:0] data_out;

    uart_top #(
        .CLK_FREQ   (50_000_000),
        .BAUD_RATE  (115200),
        .OVERSAMPLE (16)
    ) UART (
        .clk          (clk),
        .rst_n        (rst_n),
        .data_in      (data_in),
        .start_signal (start_signal),
        .rx_valid     (rx_valid),
        .data_out     (data_out)
    );

    always #10 clk = ~clk;

    localparam FRAME_TIMEOUT  = 8000;
    localparam INTERFRAME_GAP = 5000;

    integer total_errors;
    integer test_index;
    integer i;

    reg [7:0] expected_data [0:7];
    reg [7:0] received_data [0:7];

    task send_and_check;
        input [7:0] test_data;

        reg [7:0] captured;
        reg       valid_seen;
        integer   timeout;

        begin
            valid_seen = 0;
            timeout    = 0;
            captured   = 8'hxx;

            @(posedge clk); #1;
            data_in      = test_data;
            start_signal = 1'b1;

            @(posedge clk); #1;
            start_signal = 1'b0;

            while (!valid_seen && timeout < FRAME_TIMEOUT) begin
                @(posedge clk);

                if (rx_valid) begin
                    captured   = data_out;
                    valid_seen = 1'b1;
                end

                timeout = timeout + 1;
            end

            if (!valid_seen) begin
                $display("FAIL [8'h%02h]: rx_valid timeout", test_data);

                expected_data[test_index] = test_data;
                received_data[test_index] = 8'hXX;

                total_errors = total_errors + 1;
                test_index   = test_index + 1;

            end
            else if (captured !== test_data) begin
                $display("FAIL [8'h%02h]: expected 8'h%02h got 8'h%02h",
                         test_data,
                         test_data,
                         captured);

                expected_data[test_index] = test_data;
                received_data[test_index] = captured;

                total_errors = total_errors + 1;
                test_index   = test_index + 1;

            end
            else begin
                expected_data[test_index] = test_data;
                received_data[test_index] = captured;

                test_index = test_index + 1;
            end

            repeat(INTERFRAME_GAP) @(posedge clk);
        end
    endtask

    initial begin
        clk          = 1'b0;
        rst_n        = 1'b0;
        start_signal = 1'b0;
        data_in      = 8'h00;

        total_errors = 0;
        test_index   = 0;

        repeat(100) @(posedge clk);
        rst_n = 1'b1;
        repeat(100) @(posedge clk);

        $display("=== UART LOOPBACK TEST ===");

        send_and_check(8'hAD);
        send_and_check(8'h55);
        send_and_check(8'hAA);
        send_and_check(8'hFF);
        send_and_check(8'h00);
        send_and_check(8'h01);
        send_and_check(8'h80);
        send_and_check(8'hA5);

        $display("");
        $display("=== RECEIVED DATA SUMMARY ===");

        for (i = 0; i < test_index; i = i + 1) begin
            $display("Test %0d : expected = 8'h%02h, captured = 8'h%02h",
                     i + 1,
                     expected_data[i],
                     received_data[i]);
        end

        $display("=============================");
        $display("");

        if (total_errors == 0)
            $display("ALL LOOPBACK TESTS PASSED");
        else
            $display("DONE - %0d error(s)", total_errors);

        $display("=============================");

        $stop;
    end

endmodule