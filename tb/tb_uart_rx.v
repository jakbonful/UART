`timescale 1ns/1ps

module tb_receiver;

    reg  clk;
    reg  rst_n;
    reg  rx_in;

    wire over_sample_baud_tick;
    wire [7:0] data_out;
    wire rx_valid;

    // 16× oversample tick: 16 × 115200 = 1,843,200 Hz
    baudrate_gen #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(1_843_200)
    ) BRG (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(over_sample_baud_tick)
    );

    receiver RX (
        .clk(clk),
        .rst_n(rst_n),
        .over_sample_baud_tick(over_sample_baud_tick),
        .rx_in(rx_in),
        .data_out(data_out),
        .rx_valid(rx_valid)
    );

    always #10 clk = ~clk;

    // ── Task: wait N oversample ticks ───────────────────────────
    integer k;
    task wait_ticks;
        input integer n;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge over_sample_baud_tick);
        end
    endtask

    // ── Task: send one byte and verify ──────────────────────────
    integer i;
    integer byte_errors;
    integer total_errors;

    task send_and_check;
        input [7:0] test_data;
        reg   [7:0] captured;
        reg         valid_seen;
        integer     timeout;
        begin
            byte_errors = 0;
            valid_seen  = 0;
            timeout     = 0;

            $display("--- Sending 8'h%h (%b) ---", test_data, test_data);

            // Start bit: drive rx_in low for 16 oversample ticks
            rx_in = 1'b0;
            wait_ticks(16);

            // Data bits LSB first, 16 ticks each
            for (i = 0; i < 8; i = i + 1) begin
                rx_in = test_data[i];
                wait_ticks(16);
            end

            // Stop bit — drive high, wait for rx_valid
            rx_in = 1'b1;

            // Poll for rx_valid with timeout (16 ticks = one baud period)
            fork
                begin : wait_valid
                    @(posedge rx_valid);
                    @(posedge clk); #1;
                    captured   = data_out;
                    valid_seen = 1;
                    disable timeout_block;
                end
                begin : timeout_block
                    wait_ticks(16);
                    if (!valid_seen) begin
                        $display("  FAIL: rx_valid never asserted (timeout)");
                        byte_errors = byte_errors + 1;
                        disable wait_valid;
                    end
                end
            join

            // Finish stop bit period, return line to idle
            wait_ticks(8);
            rx_in = 1'b1;

            // Check captured data
            if (valid_seen) begin
                if (captured !== test_data) begin
                    $display("  FAIL: expected 8'h%h (%b), got 8'h%h (%b)",
                             test_data, test_data, captured, captured);
                    for (i = 0; i < 8; i = i + 1) begin
                        if (captured[i] !== test_data[i])
                            $display("        bit[%0d]: expected %b got %b",
                                     i, test_data[i], captured[i]);
                    end
                    byte_errors = byte_errors + 1;
                end else begin
                    $display("  PASS: captured 8'h%h", captured);
                end
            end

            total_errors = total_errors + byte_errors;

            // Inter-frame gap: one full baud period idle before next byte
            wait_ticks(16);
        end
    endtask

    // ── False-start test ────────────────────────────────────────
    task test_false_start;
        begin
            $display("--- False-start test ---");
            rx_in = 1'b0;
            wait_ticks(4);      // only 4 ticks — sample_point never fires
            rx_in = 1'b1;
            wait_ticks(32);     // let receiver settle back to IDLE

            if (rx_valid) begin
                $display("  FAIL: rx_valid asserted on false start");
                total_errors = total_errors + 1;
            end else begin
                $display("  PASS: false start correctly ignored");
            end
        end
    endtask

    // ── Stimulus ─────────────────────────────────────────────────
    initial begin
        clk          = 0;
        rst_n        = 0;
        rx_in        = 1'b1;
        total_errors = 0;

        #100;
        rst_n = 1;
        #100;

        send_and_check(8'hAD);
        send_and_check(8'h55);
        send_and_check(8'hAA);
        send_and_check(8'hFF);
        send_and_check(8'h00);
        send_and_check(8'h01);
        send_and_check(8'h80);
        test_false_start();
        send_and_check(8'hA5);

        $display("==============================");
        if (total_errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("DONE — %0d error(s)", total_errors);
        $display("==============================");

        $stop;
    end

endmodule