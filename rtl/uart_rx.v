module receiver (
    input clk,
    input rst_n,
    input over_sample_baud_tick,
    input rx_in,

    output reg [7:0] data_out,
    output reg rx_valid
);

    parameter IDLE = 4'b0001,
              START = 4'b0010,
              DATA = 4'b0100,
              STOP = 4'b1000;

    reg [3:0] state, next_state;
    reg [3:0] over_sample_counter;
    reg [2:0] bit_index;

    // sample point at middle of bit
    wire sample_point = over_sample_baud_tick && (over_sample_counter == 4'd8);

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

            IDLE: begin
                if (!rx_in)
                    next_state = START;
            end

            START: begin
                if (sample_point) begin
                    if (!rx_in)
                        next_state = DATA;
                    else
                        next_state = IDLE;
                end
            end

            DATA: begin
                if (sample_point && bit_index == 3'd7)
                    next_state = STOP;
            end

            STOP: begin
                if (sample_point && rx_in)
                    next_state = IDLE;
            end

        endcase
    end

    // oversample counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            over_sample_counter <= 0;
        else if (state == IDLE)
            over_sample_counter <= 0;
        else if (over_sample_baud_tick) begin
            if (over_sample_counter == 4'd15)
                over_sample_counter <= 0;
            else
                over_sample_counter <= over_sample_counter + 1'b1;
        end
    end

    // bit index counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_index <= 0;
        else if (state == IDLE)
            bit_index <= 0;
        else if (state == DATA && sample_point) begin
            if (bit_index < 3'd7)
                bit_index <= bit_index + 1'b1;
        end
    end

    // data sampling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 0;
        else if (state == DATA && sample_point)
            data_out[bit_index] <= rx_in;
    end

    // rx valid pulse
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_valid <= 1'b0;
        else if (state == STOP && sample_point && rx_in)
            rx_valid <= 1'b1;
        else
            rx_valid <= 1'b0;
    end

endmodule