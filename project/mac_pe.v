// mac_pe.v - Multiply-Accumulate Processing Element (optimized version)
module mac_pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input                          clk,
    input                          reset, 
    input signed [DATA_WIDTH-1:0]  a1,
    input signed [DATA_WIDTH-1:0]  a2,
    input signed [DATA_WIDTH-1:0]  w1,
    input signed [DATA_WIDTH-1:0]  w2,
    output reg signed [ACC_WIDTH-1:0] acc
);
    wire signed [2*DATA_WIDTH-1:0] product1;
    wire signed [2*DATA_WIDTH-1:0] product2;
    
    assign product1 = a1 * w1;
    assign product2 = a2 * w2;
    
    always @(posedge clk) begin
        if (reset) begin
            acc <= 0;
        end
        else begin
            acc <= acc + product1 + product2;
        end
    end
endmodule