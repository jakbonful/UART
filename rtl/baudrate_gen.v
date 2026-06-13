module baudrate_gen #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input clk,
    input rst_n,
    output reg baud_tick
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg [$clog2(CLKS_PER_BIT)-1:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            baud_tick <= 0;
        end
        else if (counter == CLKS_PER_BIT - 1) begin
            counter <= 0;
            baud_tick <= 1'b1;
        end
        else begin
            counter <= counter + 1'b1;
            baud_tick <= 1'b0;
        end
    end

endmodule