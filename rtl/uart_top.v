module uart_top #(
    parameter CLK_FREQ = 50_000_000,
    parameter TX_BAUD_RATE = 115200,
    parameter RX_BAUD_RATE = 16 * 115200
) (
    input clk,
    input rst_n,
    input [7:0] data_in,
    input start_signal,

    output rx_valid,
    output [7:0] data_out
);

    // Connecting Wires
    wire serial_line;
    wire tx_baud_tick;
    wire rx_baud_tick;
    

    // Transmitter Clock 
    baudrate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(TX_BAUD_RATE)
    ) BRG_TX (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(tx_baud_tick)
    );
    
    // Receiver Clock 
    baudrate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(RX_BAUD_RATE)
    ) BRG_RX (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(rx_baud_tick)
    );


    // Transmitter
    transmitter TX1 (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(start_signal),
        .baud_tick(tx_baud_tick),
        .data_in(data_in),
        .tx_out(serial_line)
    );

    // Receiver
    receiver RX1 (
        .clk(clk),
        .rst_n(rst_n),
        .over_sample_baud_tick(rx_baud_tick),
        .rx_in(serial_line),
        .data_out(data_out),
        .rx_valid(rx_valid)
    );
    
endmodule