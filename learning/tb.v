`timescale 1ns/1ps
module tb;

    wire [15:0] y1, y2;

    // Instantiate DUT
    matrix_vector_mul dut (.y1(y1), .y2(y2));

    initial begin
        #1; // wait for combinational logic to settle
        $display("Result: y1 = %d, y2 = %d", y1, y2);
        #1;
        $finish;
    end

endmodule
