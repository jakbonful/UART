`timescale 1ns/1ps

module tb_transmitter;

    reg clk;
    reg rst_n;
    reg tx_start;
    reg [7:0] data_in;

    wire baud_tick;
    wire tx_out;

    baudrate_gen #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(115200)
    ) BRG (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick)
    );

    transmitter TX (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .baud_tick(baud_tick),
        .data_in(data_in),
        .tx_out(tx_out)
    );

    always #10 clk = ~clk;

    integer i;
    integer total_errors;
    integer byte_errors;
    reg [9:0] frame;

    // ── Task: transmit one byte and verify the captured frame ──
    task send_and_check;
        input [7:0] test_data;
        begin
            byte_errors = 0;

            // Load data and pulse tx_start
            data_in = test_data;
            @(posedge clk);
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;

            // Start bit — sample as soon as TX goes low
            wait(tx_out == 1'b0);
            #1;
            frame[0] = tx_out;

            // 8 data bits — after each baud_tick the FSM shifts;
            // wait for clk to register new state then sample
            for (i = 0; i < 8; i = i + 1) begin
                @(posedge baud_tick);
                @(posedge clk);
                #1;
                frame[i+1] = tx_out;
            end

            // Stop bit
            @(posedge baud_tick);
            @(posedge clk);
            #1;
            frame[9] = tx_out;

            // Wait for TX to return to idle before next byte
            @(posedge baud_tick);
            @(posedge clk);
            #1;

            // ── Check ──
            $display("--- Byte 8'h%h ---", test_data);
            $display("  Expected : start=0 data=%b stop=1", test_data);
            $display("  Captured : start=%b data=%b%b%b%b%b%b%b%b stop=%b",
                     frame[0],
                     frame[1],frame[2],frame[3],frame[4],
                     frame[5],frame[6],frame[7],frame[8],
                     frame[9]);

            if (frame[0] !== 1'b0) begin
                $display("  FAIL: start bit error");
                byte_errors = byte_errors + 1;
            end

            for (i = 0; i < 8; i = i + 1) begin
                if (frame[i+1] !== test_data[i]) begin
                    $display("  FAIL: data bit %0d — expected %b got %b",
                             i, test_data[i], frame[i+1]);
                    byte_errors = byte_errors + 1;
                end
            end

            if (frame[9] !== 1'b1) begin
                $display("  FAIL: stop bit error");
                byte_errors = byte_errors + 1;
            end

            if (byte_errors == 0)
                $display("  PASS");

            total_errors = total_errors + byte_errors;
        end
    endtask

    // ── Stimulus ───────────────────────────────────────────────
    initial begin
        clk          = 0;
        rst_n        = 0;
        tx_start     = 0;
        data_in      = 0;
        total_errors = 0;

        #100;
        rst_n = 1;
        #100;

        // Add or remove bytes freely here
        send_and_check(8'hAD);   // 10101101
        send_and_check(8'h55);   // 01010101
        send_and_check(8'hFF);   // 11111111
        send_and_check(8'h00);   // 00000000
        send_and_check(8'hA5);   // 10100101

        $display("==============================");
        if (total_errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("DONE — %0d error(s)", total_errors);
        $display("==============================");

        $stop;
    end

endmodule