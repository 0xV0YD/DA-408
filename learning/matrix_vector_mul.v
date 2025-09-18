module matrix_vector_mul #(
    parameter N = 2,   // number of inputs (columns)
    parameter M = 2    // number of outputs (rows)
)(
    input  wire [7:0]  x [0:N-1],          // input vector
    input  wire [7:0]  W [0:M-1][0:N-1],   // weight matrix
    input  wire [15:0] B [0:M-1],          // bias vector
    output wire [15:0] Y [0:M-1]           // output vector
);
    genvar i, j;
    generate
        for (i = 0; i < M; i = i + 1) begin : ROWS
            wire [15:0] sum [0:N];  
            assign sum[0] = 16'd0;

            for (j = 0; j < N; j = j + 1) begin : COLS
                mac_unit mac (
                    .a(W[i][j]),
                    .b(x[j]),
                    .c(sum[j]),
                    .out(sum[j+1])
                );
            end

            assign Y[i] = sum[N] + B[i];
        end
    endgenerate
endmodule
