`timescale 1ns/1ps

module tb_receiver;

    reg  clk;
    reg  rst_n;
    reg  rx_in;

    wire over_sample_baud_tick;
    wire [7:0] data_out;
    wire rx_valid;

    // Generate 16x oversample tick (16 × 115200 = 1,843,200 Hz)
    baudrate_gen #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(1_843_200)
    ) baud_inst (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(over_sample_baud_tick)
    );

    receiver dut (
        .clk(clk),
        .rst_n(rst_n),
        .over_sample_baud_tick(over_sample_baud_tick),
        .rx_in(rx_in),
        .data_out(data_out),
        .rx_valid(rx_valid)
    );

    always #10 clk = ~clk;

    // ── Task: wait for N oversample ticks ───────────────────────
    // Used to hold rx_in stable for one bit period (16 ticks)
    // or fraction thereof. The receiver samples at tick 8
    // (midpoint) so bit must be stable well before then.
    task wait_ticks;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge over_sample_baud_tick);
        end
    endtask

    // ── Task: send one UART frame and verify ────────────────────
    integer i;
    integer byte_errors;
    integer total_errors;

    task send_and_check;
        input [7:0] test_data;
        reg  [7:0] captured;
        reg        valid_seen;
        begin
            byte_errors = 0;
            valid_seen  = 0;

            $display("--- Sending 8'h%h (%b) ---", test_data, test_data);

            // ── Start bit: drive rx_in low ──────────────────────
            // The receiver detects the falling edge in IDLE and
            // resets its counter to 0 on the next clock.
            // Hold for 16 ticks so the counter reaches 15 and
            // start_done fires, transitioning to DATA.
            rx_in = 1'b0;
            wait_ticks(16);

            // ── Data bits: LSB first, 16 ticks each ─────────────
            for (i = 0; i < 8; i = i + 1) begin
                rx_in = test_data[i];
                wait_ticks(16);
            end

            // ── Stop bit ─────────────────────────────────────────
            rx_in = 1'b1;

            // rx_valid pulses one clock after the STOP sample_point
            // (sample_point is at tick 8 of the stop bit period).
            // Wait until rx_valid rises, then capture data_out.
            // Timeout after 16 ticks to avoid hanging on failure.
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

            // Hold stop bit for remainder of period then go idle
            // (rx_in already 1 — just finish out the stop window)
            wait_ticks(8);
            rx_in = 1'b1;   // line idles high

            // ── Verify ───────────────────────────────────────────
            if (valid_seen) begin
                if (captured !== test_data) begin
                    $display("  FAIL: expected 8'h%h (%b), got 8'h%h (%b)",
                             test_data, test_data, captured, captured);
                    // Show which bits are wrong
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

            // Inter-frame gap: let line sit idle for one full baud
            // period so receiver returns cleanly to IDLE
            wait_ticks(16);
        end
    endtask

    // ── False-start test ────────────────────────────────────────
    // Drive rx_in low briefly (< 8 ticks), then back high.
    // Receiver should reject it and stay/return to IDLE.
    task test_false_start;
        begin
            $display("--- False-start test ---");
            rx_in = 1'b0;
            wait_ticks(4);          // only 4 ticks — sample_point never fires
            rx_in = 1'b1;
            wait_ticks(16);         // let receiver settle back to IDLE

            if (rx_valid) begin
                $display("  FAIL: rx_valid asserted on false start");
                total_errors = total_errors + 1;
            end else begin
                $display("  PASS: false start correctly ignored");
            end
        end
    endtask

    // ── Stimulus ────────────────────────────────────────────────
    initial begin
        clk          = 0;
        rst_n        = 0;
        rx_in        = 1'b1;    // idle line is high
        total_errors = 0;

        #100;
        rst_n = 1;
        #100;

        // Standard bytes
        send_and_check(8'hAD);  // 10101101
        send_and_check(8'h55);  // 01010101 — alternating
        send_and_check(8'hAA);  // 10101010 — alternating (inverted)
        send_and_check(8'hFF);  // 11111111 — all ones (stresses start bit)
        send_and_check(8'h00);  // 00000000 — all zeros (stresses stop bit)
        send_and_check(8'h01);  // LSB only
        send_and_check(8'h80);  // MSB only

        // False start (glitch on the line)
        test_false_start();

        // One more clean byte after the false start
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