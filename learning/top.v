module top;
    // Parameters
    localparam N = 2;  // number of inputs
    localparam M = 3;  // number of outputs

    // Input vector X = [1, 2]
    wire [7:0] x [0:N-1];
    assign x[0] = 8'd1;
    assign x[1] = 8'd2;

    // Weight matrix W =
    // [2 3]
    // [4 5]
    // [6 7]
    wire [7:0] W [0:M-1][0:N-1];
    assign W[0][0] = 8'd2;  assign W[0][1] = 8'd3;
    assign W[1][0] = 8'd4;  assign W[1][1] = 8'd5;
    assign W[2][0] = 8'd6;  assign W[2][1] = 8'd7;

    // Bias vector B = [1, 1, 1]
    wire [15:0] B [0:M-1];
    assign B[0] = 16'd1;
    assign B[1] = 16'd1;
    assign B[2] = 16'd1;

    // Output vector Y
    wire [15:0] Y [0:M-1];

    // Instantiate the matrix-vector multiplier
    matrix_vector_mul #(.N(N), .M(M)) uut (
        .x(x), .W(W), .B(B), .Y(Y)
    );
endmodule
