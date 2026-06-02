module transmitter (
    input clk,
    input rst_n,
    input tx_start,
    input baud_tick,
    input [7:0] data_in,

    output reg tx_out // transmitter output
);

// ONE-HOT STATE enconding
parameter [3:0] IDLE = 4'b0001,
                START = 4'b0010,
                DATA = 4'b0100,
                STOP = 4'b1000;

reg [3:0] state;   // sequential part
reg [3:0] next_state; // combinational part
reg [2:0] bit_index; // counter

// State Register
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
        IDLE  : begin
             if (tx_start == 1'b1) begin
                next_state = START;
            end else begin
                next_state = IDLE;
            end  
        end
        START : begin
            if (baud_tick) begin
                next_state = DATA;
            end else begin
                next_state = START;
            end            
        end
        DATA : begin
            if (baud_tick) begin
                if (bit_index == 3'd7) begin
                    next_state = STOP;
                end else begin
                    next_state = DATA;
                end
            end else begin
                    next_state = DATA;
            end
        end
        STOP : begin
            if (baud_tick) begin
                    next_state = IDLE;
                end else begin
                    next_state = STOP;
                end
            end   
        default: begin
            next_state = state;
        end   
    endcase
end

// Datapath Register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_index <= 0;
    end else if (state == DATA && baud_tick) begin
        bit_index <= bit_index + 1;
    end else if (state == IDLE) begin
        bit_index <= 0;
    end
end

always @(*) begin
    case (state)
        IDLE : begin
            tx_out = 1'b1;
        end
        START : begin
            tx_out = 1'b0;
        end
        DATA : begin
            tx_out = data_in[bit_index];
        end
        STOP : begin
            tx_out = 1'b1;
        end
        default: begin
            tx_out = 1'b1; // should always remain high
        end
    endcase
end


endmodule