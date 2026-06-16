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
              DATA  = 4'b0100,
              STOP  = 4'b1000;

    reg [3:0] state, next_state;
    reg [3:0] over_sample_counter;
    reg [2:0] bit_index;

    wire sample_point = over_sample_baud_tick && (over_sample_counter == 4'd8);
    wire start_done = over_sample_baud_tick && (over_sample_counter == 4'd15);
        
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(posedge clk) begin
        if (state != next_state)
            $display("T=%0t state %b -> %b", $time, state, next_state);
    end

    // Next state logic
    always @(*) begin
        next_state = state;

        case (state)

            IDLE: begin
                if (!rx_in)
                    next_state = START;
            end

            START: begin
                if (sample_point && rx_in) begin
                        next_state = IDLE; // False start, go back to IDLE
                end else if (start_done) begin
                        next_state = DATA;
                end
            end

            DATA: begin
                if (sample_point && bit_index == 3'd7)
                    next_state = STOP;
            end

            STOP: begin
                if (sample_point)
                    next_state = IDLE;
            end

        endcase
    end

    // Over-sample counter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            over_sample_counter <= 0;

        else if (state == IDLE && !rx_in) begin
            over_sample_counter <= 0;
            $display("T=%0t IDLE falling edge detected, counter reset", $time);
        end

        else if (over_sample_baud_tick) begin
            if (over_sample_counter == 4'd15) begin
                over_sample_counter <= 0;
                $display("T=%0t counter wrapped to 0, state=%b", $time, state);
            end else begin
                over_sample_counter <= over_sample_counter + 1'b1;
                $display("T=%0t counter=%0d state=%b", $time, over_sample_counter, state);
            end
        end
    end

    // Bit index logic
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

    // Data output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 0;

        else if (state == DATA && sample_point)
            data_out[bit_index] <= rx_in;
    end

    // RX valid logic 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_valid <= 1'b0;
        else
            rx_valid <= (state == STOP && sample_point);
    end

endmodule