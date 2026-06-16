module transmitter (
    input clk,
    input rst_n,
    input tx_start,
    input baud_tick,
    input [7:0] data_in,

    output reg tx_out
);

    parameter IDLE = 4'b0001,
              START = 4'b0010,
              DATA  = 4'b0100,
              STOP  = 4'b1000;

    reg [3:0] state, next_state;
    reg [2:0] bit_index;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(posedge clk) begin
        if (state != next_state)
            $display("TX T=%0t state %b -> %b tx_start=%b", $time, state, next_state, tx_start);
    end

    // Next state logic
    always @(*) begin
        next_state = state;

        case (state)
            IDLE:  if (tx_start) next_state = START;

            START: if (baud_tick) next_state = DATA;

            DATA:  if (baud_tick && bit_index == 3'd7) next_state = STOP;

            STOP:  if (baud_tick) next_state = IDLE;
        endcase
    end

    // Bit index logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_index <= 0;

        else if (state == IDLE)
            bit_index <= 0;

        else if (state == DATA && baud_tick) begin
            if (bit_index < 3'd7)
                bit_index <= bit_index + 1'b1;
        end
    end

    // Output logic
    always @(*) begin
        case (state)
            IDLE:  tx_out = 1'b1;
            START: tx_out = 1'b0;
            DATA:  tx_out = data_in[bit_index];
            STOP:  tx_out = 1'b1;
            default: tx_out = 1'b1;
        endcase
    end

endmodule