`timescale 1ns/1ps

module receiver (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       over_sample_baud_tick,
    input  wire       rx_in,
    output reg  [7:0] data_out,
    output reg        rx_valid
);

    localparam IDLE  = 4'b0001,
               START = 4'b0010,
               DATA  = 4'b0100,
               STOP  = 4'b1000;

    reg [3:0] state, next_state;
    reg [3:0] over_sample_counter;
    reg [2:0] bit_index;
    reg       rx_in_prev;

    wire falling_edge  = rx_in_prev && !rx_in;
    wire sample_point  = over_sample_baud_tick && (over_sample_counter == 4'd8);
    wire start_done    = over_sample_baud_tick && (over_sample_counter == 4'd15);

    // ── rx_in pipeline register for edge detection ───────────────
    always @(posedge clk or negedge rst_n)
        if (!rst_n) rx_in_prev <= 1'b1;
        else        rx_in_prev <= rx_in;

    // ── State register ───────────────────────────────────────────
    always @(posedge clk or negedge rst_n)
        if (!rst_n) state <= IDLE;
        else        state <= next_state;

    // ── Next-state logic ─────────────────────────────────────────
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:  if (falling_edge)              next_state = START;
            START: begin
                   if (sample_point && rx_in)     next_state = IDLE;   // false start
                   else if (start_done)            next_state = DATA;
                   end
            DATA:  if (sample_point && bit_index == 3'd7)
                                                   next_state = STOP;
            STOP:  if (sample_point)               next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // ── Over-sample counter ──────────────────────────────────────
    // Reset only on the actual falling edge (one-shot), not level.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            over_sample_counter <= 4'd0;
        else if (state == IDLE && falling_edge) begin
            over_sample_counter <= 4'd0;
            $display("T=%0t IDLE falling edge detected, counter reset", $time);
        end
        else if (over_sample_baud_tick) begin
            if (over_sample_counter == 4'd15) begin
                over_sample_counter <= 4'd0;
                $display("T=%0t counter wrapped to 0, state=%b", $time, state);
            end else begin
                over_sample_counter <= over_sample_counter + 1'b1;
                $display("T=%0t counter=%0d state=%b",
                         $time, over_sample_counter, state);
            end
        end
    end

    // ── Bit index ────────────────────────────────────────────────
    // Reset in IDLE or on any false-start return to IDLE via START
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_index <= 3'd0;
        else if (state == IDLE || (state == START && next_state == IDLE))
            bit_index <= 3'd0;
        else if (state == DATA && sample_point && bit_index < 3'd7)
            bit_index <= bit_index + 1'b1;
    end

    // ── Data register ────────────────────────────────────────────
    // Clear on entry to START so no stale bits survive from previous frame.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 8'd0;
        else if (state == IDLE && falling_edge)
            data_out <= 8'd0;                    // clear on start of new frame
        else if (state == DATA && sample_point)
            data_out[bit_index] <= rx_in;
    end

    // ── rx_valid (registered, one-cycle pulse) ───────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rx_valid <= 1'b0;
        else        rx_valid <= (state == STOP && sample_point);
    end

    // ── State-change debug ───────────────────────────────────────
    always @(posedge clk) begin
        if (state != next_state)
            $display("T=%0t state %b -> %b", $time, state, next_state);
    end
endmodule