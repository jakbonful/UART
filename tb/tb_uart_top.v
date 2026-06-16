`timescale 1ns/1ps

module tb_uart();

    parameter CLK_FREQ          = 50_000_000;
    parameter TX_BAUD_RATE      = 115200;
    parameter RX_OVERSAMPLE_RATE = 16 * 115200;

    reg clk = 0;
    reg rst_n;
    reg [7:0] data_in;
    reg start_signal;

    wire rx_valid;
    wire [7:0] data_out;

    // DUT
    uart_top #(
        .CLK_FREQ(CLK_FREQ),
        .TX_BAUD_RATE(TX_BAUD_RATE),
        .RX_OVERSAMPLE_RATE(RX_OVERSAMPLE_RATE)
    ) UART0 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .start_signal(start_signal),
        .rx_valid(rx_valid),
        .data_out(data_out)
    );

    // Clock
    always #10 clk = ~clk;

    
    task wait_rx_valid;
        integer timeout;
        begin
            timeout = 0;

            while (rx_valid !== 1'b1 && timeout < 200000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= 200000) begin
                $display("TIMEOUT: rx_valid never asserted");
                $stop;
            end

            // IMPORTANT: consume pulse cleanly
            @(posedge clk);
        end
    endtask


    // SEND BYTE TASK
    task send_byte;
        input [7:0] tx_byte;
        begin
            data_in = tx_byte;
            start_signal = 1'b0;

            @(posedge clk);
            start_signal = 1'b1;

            @(posedge clk);
            start_signal = 1'b0;

            wait_rx_valid();

            if (data_out == tx_byte)
                $display("PASS: received 0x%h", data_out);
            else
                $display("FAIL: expected 0x%h got 0x%h",
                         tx_byte, data_out);
        end
    endtask

   
    // TEST SEQUENC
    initial begin
        rst_n = 0;
        data_in = 0;
        start_signal = 0;

        repeat (5) @(posedge clk);
        rst_n = 1;

        repeat (2) @(posedge clk);

        send_byte(8'hA7);
        send_byte(8'h3C);
        send_byte(8'h55);
        send_byte(8'hFF);

        $display("All transmissions complete");
        $stop;
    end

endmodule