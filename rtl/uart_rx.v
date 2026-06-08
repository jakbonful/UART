module receiver (
    input clk,
    input rst_n,
    input over_sample_baud_tick,
    input rx_in,
    output reg [7:0] data_out,
    output reg rx_valid

);
    // Module Parameters
    reg [2:0] bit_index;
    reg [4:0] over_sample_counter;

    reg [3:0] state; // State Register
    reg [3:0] next_state;   // Next State Register

    // ONE HOT Encoding
    parameter IDLE = 4'b0001,
              START = 4'b0010,
              DATA = 4'b0100,
              STOP = 4'b1000;

    // State Register Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
            case (state)
                IDLE : begin
                    if (!rx_in) begin
                        next_state = START;
                    end else begin
                        next_state = IDLE;
                    end
                end 
                START : begin
                    if (!rx_in) begin
                        if (over_sample_baud_tick) begin
                            if (over_sample_counter == 4'd8) begin // START bit is valid at the 8th over-sample tick
                                next_state = DATA;
                            end else begin
                                next_state = START;
                            end
                        end
                    end else begin
                            next_state = IDLE;
                    end
                end
                DATA : begin
                   if (over_sample_baud_tick && bit_index == 3'd7 && over_sample_counter == 4'd15) begin
                        next_state = STOP;
                   end else begin
                        next_state = DATA;
                   end
                end
                STOP : begin
                   if (over_sample_baud_tick) begin
                        if (rx_in) begin
                            if (over_sample_counter = 4'd8) begin
                                next_state = IDLE;
                            end
                        end else begin
                            next_state = STOP;
                        end
                   end else begin
                            next_state = STOP;
                   end
                end

                default: begin
                    next_state = state;
                end
            endcase
    end

    // Datapath 
        // Over Sample Counter Logic
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                over_sample_counter <= 0;
            end else if (over_sample_baud_tick) begin
                if (over_sample_counter == 4'd15) begin
                    over_sample_counter <= 0;
                end else begin
                    over_sample_counter <= over_sample_counter + 1'b1;
                end
            end       
        end

        // Bit Index Counter
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                bit_index <= 0;
            end else if (state == DATA && over_sample_counter == 4'd15) begin
                bit_index <= bit_index + 1'b1;
            end else if (state == IDLE) begin
                bit_index <= 0;
            end
        end


        // Validity Bit
        always @(posedge clk or  negedge rst_n) begin
            if (!rst_n) begin
                rx_valid <= 0'b0;
            end else if (state == STOP && over_sample_counter == 4'd8 && rx_in) begin
                rx_valid <= 1'b1; 
            end else begin
                rx_valid <= 0'b0;
            end
        end

        // Output Logic
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                data_out <= 0;
            end else if (state == DATA && over_sample_counter == 4'd8) begin
                data_out[bit_index] <= rx_in;
            end
        end
endmodule