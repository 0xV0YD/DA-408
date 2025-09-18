`timescale 1ns/1ps

module tb_mac;
    reg clk, rst;
    reg  signed [7:0] a, b;
    wire signed [15:0] result;

    // Instantiate MAC
    mac_pe uut (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .result(result)
    );

    // Clock
    always #5 clk = ~clk;

    initial begin
        $dumpfile("mac_test.vcd");
        $dumpvars(0, tb_mac);

        clk = 0;
        rst = 1; a = 0; b = 0;
        #10 rst = 0;

        // Apply inputs
        a = 3; b = 4;   // result = 12
        #10;
        a = 2; b = -1;  // result = 12 + (-2) = 10
        #10;
        a = -5; b = 2;  // result = 10 + (-10) = 0
        #10;

        $display("Final result = %d", result);
        $finish;
    end
endmodule
