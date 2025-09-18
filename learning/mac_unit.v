module mac_unit (
    input wire [7:0] a,
    input wire [7:0] b,
    input wire [15:0] c,
    output wire [15:0] out
);

    assign out = (a * b) + c;

endmodule
