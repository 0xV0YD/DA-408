module mac(
    input wire clk,
    input wire [7:0] a, b,
    input wire [15:0] c,
    output reg [15:0] y
);
    always @(posedge clk) begin
        y<=(a*b)+c;
    end
endmodule