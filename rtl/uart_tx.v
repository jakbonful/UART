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
    reg [7:0] shift_reg;

    // state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // next state logic
    always @(*) begin
        next_state = state;

        case (state)
            IDLE:  if (tx_start) next_state = START;
            START: if (baud_tick) next_state = DATA;
            DATA:  if (baud_tick && bit_index == 3'd7) next_state = STOP;
            STOP:  if (baud_tick) next_state = IDLE;
        endcase
    end

    // datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_index <= 0;
            shift_reg <= 0;
        end
        else begin
            if (state == IDLE) begin
                bit_index <= 0;
                if (tx_start)
                    shift_reg <= data_in;
            end
            else if (state == DATA && baud_tick) begin
                if (bit_index < 3'd7)
                    bit_index <= bit_index + 1'b1;
            end
        end
    end

    // output
    always @(*) begin
        case (state)
            IDLE:  tx_out = 1'b1;
            START: tx_out = 1'b0;
            DATA:  tx_out = shift_reg[bit_index];
            STOP:  tx_out = 1'b1;
            default: tx_out = 1'b1;
        endcase
    end

    // debug
    // Before (fires on baud_tick posedge — state not yet updated)
    always @(posedge baud_tick) begin
        $display("T=%0t STATE=%b BIT=%0d TX=%b", $time, state, bit_index, tx_out);
    end

    // After (fires on clk, gated by baud_tick — state is registered and stable)
    always @(posedge clk) begin
        if (baud_tick)
            $display("T=%0t STATE=%b BIT=%0d TX=%b", $time, state, bit_index, tx_out);
    end

endmodule