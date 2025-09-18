`timescale 1ns/1ps
module mac_tb;
    reg clk;
    reg [7:0] a, b;
    reg [15:0] c;
    wire [15:0] y;

    mac uut (.clk(clk), .a(a), .b(b), .c(c), .y(y));

    initial begin
        $dumpfile("mac_tb.vcd");   // for GTKWave
        $dumpvars(0, mac_tb);

        clk = 0;
        a = 8'd3; b = 8'd4; c = 16'd5;
        #10;
        a = 8'd10; b = 8'd2; c = 16'd7;
        #10;
        $finish;
    end

    always #5 clk = ~clk; // clock toggle
endmodule