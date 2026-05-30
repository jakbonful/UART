module baudrate_gen #(
    parameter CLK_FREQ = 50_000_000, // 50 MHz;
    parameter BAUD_RATE = 115200 // 115200 changes in one second
) (
    input clk,
    input rst_n,
    output reg baud_tick
);

    localparam CLKS_PER_BIT = CLK_FREQ/BAUD_RATE;
    reg [$clog2(CLKS_PER_BIT)-1:0] counter;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin // clears all inputs and outputs
        counter <= 0;
        baud_tick <= 0;
    end  
    else if (counter == CLKS_PER_BIT -1) begin
        counter <= 0; // reset counter
        baud_tick <= 1;
    end 
    else begin
        counter <= counter + 1'b1;
        baud_tick <= 0; // tick remains zero
    end
        
end
   
    
endmodule