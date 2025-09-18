`timescale 1ns / 1ps

module layer2_mnist #(
    parameter DATA_WIDTH   = 8,
    parameter VECTOR_LEN   = 32,   // Input from layer 1
    parameter NUM_PES      = 10,   // 10 output classes
    parameter ACC_WIDTH    = 32
)(
    input clk, 
    input reset, 
    input start, 
    input wire signed [(ACC_WIDTH*VECTOR_LEN)-1:0] input_vector,  // From layer 1
    output reg done, 
    output wire signed [(ACC_WIDTH*NUM_PES)-1:0] result_vector,
    output reg [3:0] predicted_class
); 

localparam CYCLES_NEEDED = VECTOR_LEN / 2;  // 16 cycles (2 inputs per cycle)
localparam S_IDLE       = 2'b00; 
localparam S_PROCESSING = 2'b01; 
localparam S_DONE       = 2'b10;

reg [1:0]  state_reg, next_state; 
reg [4:0]  cycle_counter;  // 5 bits for up to 32 cycles
reg pe_reset; 

// Memory arrays
reg signed [DATA_WIDTH-1:0] weight_mem [0:VECTOR_LEN-1][0:NUM_PES-1];
reg signed [DATA_WIDTH-1:0] bias_mem [0:NUM_PES-1];

// Unpack input vector
reg signed [ACC_WIDTH-1:0] layer1_outputs [0:VECTOR_LEN-1];

genvar u;
generate
    for (u = 0; u < VECTOR_LEN; u = u + 1) begin : unpack_layer1
        assign layer1_outputs[u] = input_vector[(u+1)*ACC_WIDTH-1 : u*ACC_WIDTH];
    end
endgenerate

// Scale down layer1 outputs to DATA_WIDTH
wire signed [DATA_WIDTH-1:0] a1_feed, a2_feed;

assign a1_feed = (layer1_outputs[cycle_counter*2] > 127) ? 8'd127 :
                 (layer1_outputs[cycle_counter*2] < -128) ? -8'd128 :
                 layer1_outputs[cycle_counter*2][DATA_WIDTH-1:0];

assign a2_feed = (cycle_counter*2+1 < VECTOR_LEN) ? 
                 ((layer1_outputs[cycle_counter*2+1] > 127) ? 8'd127 :
                  (layer1_outputs[cycle_counter*2+1] < -128) ? -8'd128 :
                  layer1_outputs[cycle_counter*2+1][DATA_WIDTH-1:0]) : 8'h00;

// PE outputs
wire signed [ACC_WIDTH-1:0] pe_acc_out [0:NUM_PES-1];

// Memory initialization
initial begin
    $display("Layer2: Loading memory files...");
    $readmemh("output/weights2.mem", weight_mem);
    $readmemh("output/biases2.mem", bias_mem);
    $display("Layer2: Memory files loaded successfully");
end

// State machine
always @(posedge clk) begin
    if (reset) begin
        state_reg <= S_IDLE;
        cycle_counter <= 0;
    end else begin
        state_reg <= next_state;
        if (next_state == S_PROCESSING) begin
            if (cycle_counter == CYCLES_NEEDED-1)
                cycle_counter <= 0;
            else
                cycle_counter <= cycle_counter + 1;
        end
    end
end

always @(*) begin
    next_state = state_reg;
    pe_reset = 1'b1;
    done = 1'b0;
    
    case(state_reg)
        S_IDLE: if (start) begin next_state=S_PROCESSING; pe_reset=1'b0; end
        S_PROCESSING: begin pe_reset=1'b0;
            if (cycle_counter==CYCLES_NEEDED-1) next_state=S_DONE;
        end
        S_DONE: begin done=1'b1; next_state=S_IDLE; end
    endcase
end

// Generate MAC PEs for each output class
genvar i;
generate
    for(i=0;i<NUM_PES;i=i+1) begin : pe_instances
        mac_pe #(
            .DATA_WIDTH(DATA_WIDTH),
            .ACC_WIDTH(ACC_WIDTH)
        ) pe_inst (
            .clk(clk),
            .reset(pe_reset),
            .a1(a1_feed),
            .a2(a2_feed),
            .w1(weight_mem[cycle_counter*2][i]),
            .w2((cycle_counter*2+1 < VECTOR_LEN) ? weight_mem[cycle_counter*2+1][i] : 8'h00),
            .acc(pe_acc_out[i])
        );
    end
endgenerate

// Add biases and find maximum
reg signed [ACC_WIDTH-1:0] final_results [0:NUM_PES-1];
reg signed [ACC_WIDTH-1:0] max_value;
reg bias_added;

always @(posedge clk) begin
    if (reset) begin
        bias_added <= 0;
        predicted_class <= 0;
        max_value <= -2147483648;
        for (integer j = 0; j < NUM_PES; j = j + 1)
            final_results[j] <= 0;
    end
    else if (state_reg == S_DONE && !bias_added) begin
        max_value <= -2147483648;
        for (integer j = 0; j < NUM_PES; j = j + 1) begin
            // ✅ Sign-extend bias to ACC_WIDTH and add to PE output
            final_results[j] <= $signed(pe_acc_out[j]) + 
                                $signed({{(ACC_WIDTH-DATA_WIDTH){bias_mem[j][DATA_WIDTH-1]}}, bias_mem[j]});
            
            // ✅ Compare using correctly signed final result
            if (final_results[j] > max_value) begin
                max_value <= final_results[j];
                predicted_class <= j;
            end
        end
        bias_added <= 1;
    end
    else if (state_reg == S_IDLE) begin
        bias_added <= 0;
        max_value <= -2147483648;
    end
end

// Pack results into output vector
genvar k;
generate
    for(k=0;k<NUM_PES;k=k+1) begin : assign_slices
        assign result_vector[(k+1)*ACC_WIDTH-1 : k*ACC_WIDTH] = final_results[k];
    end
endgenerate

endmodule
