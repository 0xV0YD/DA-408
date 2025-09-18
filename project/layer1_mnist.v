`timescale 1ns / 1ps

module layer1_mnist #(
    parameter DATA_WIDTH   = 8,
    parameter VECTOR_LEN   = 784,
    parameter NUM_PES      = 32,  // 32 output neurons
    parameter ACC_WIDTH    = 32
)(
    input clk, 
    input reset, 
    input start, 
    output reg done, 
    output wire signed [(ACC_WIDTH * NUM_PES)-1:0] result_vector
); 

localparam CYCLES_NEEDED = VECTOR_LEN / 2;  // 392 cycles (2 inputs per cycle)
localparam S_IDLE       = 2'b00; 
localparam S_PROCESSING = 2'b01; 
localparam S_DONE       = 2'b10;

reg [1:0]  state_reg, next_state; 
reg [8:0]  cycle_counter; 
reg pe_reset; 

// Memory arrays
reg [DATA_WIDTH-1:0] input_vector_mem [0:VECTOR_LEN-1];  // Unsigned input (0-255)
reg signed [DATA_WIDTH-1:0] weight_mem [0:VECTOR_LEN-1][0:NUM_PES-1];
reg signed [DATA_WIDTH-1:0] bias_mem [0:NUM_PES-1];

// PE outputs
wire signed [ACC_WIDTH-1:0] pe_acc_out [0:NUM_PES-1];

// Input feeds
wire [DATA_WIDTH-1:0] a1_feed, a2_feed;
wire signed [DATA_WIDTH-1:0] a1_signed, a2_signed;

// Memory initialization
initial begin
    $display("Layer1: Loading memory files...");
    $readmemh("output/input_image.mem", input_vector_mem);
    $readmemh("output/weights1.mem", weight_mem);
    $readmemh("output/biases1.mem", bias_mem);
    $display("Layer1: Memory files loaded successfully");
end

// Convert unsigned input to signed for computation
assign a1_feed = input_vector_mem[cycle_counter * 2];
assign a2_feed = (cycle_counter * 2 + 1 < VECTOR_LEN) ? input_vector_mem[cycle_counter * 2 + 1] : 8'h00;
assign a1_signed = {1'b0, a1_feed[6:0]};  // Convert to signed (0-127 range)
assign a2_signed = {1'b0, a2_feed[6:0]};  // Convert to signed (0-127 range)

// State machine
always @(posedge clk) begin
    if (reset) begin 
        state_reg <= S_IDLE; 
        cycle_counter <= 0; 
    end else begin 
        state_reg <= next_state; 
        if (next_state == S_PROCESSING) begin 
            if (cycle_counter == CYCLES_NEEDED - 1) begin 
                cycle_counter <= 0; 
            end else begin 
                cycle_counter <= cycle_counter + 1; 
            end
        end 
    end
end

always @(*) begin
    next_state = state_reg; 
    pe_reset = 1'b1; 
    done = 1'b0;
    
    case(state_reg)
        S_IDLE: begin
            if (start) begin 
                next_state = S_PROCESSING; 
                pe_reset = 1'b0;
            end
        end 
        S_PROCESSING: begin 
            pe_reset = 1'b0;
            if (cycle_counter == CYCLES_NEEDED - 1) begin 
                next_state = S_DONE;
            end
        end
        S_DONE: begin
            done = 1'b1;
            next_state = S_IDLE;
        end
    endcase
end

// Generate MAC PEs for each output neuron
genvar i; 
generate
    for(i = 0; i < NUM_PES; i = i + 1) begin : pe_instances
        mac_pe #(
            .DATA_WIDTH(DATA_WIDTH),
            .ACC_WIDTH(ACC_WIDTH)
        ) 
        pe_inst (
            .clk(clk),
            .reset(pe_reset),
            .a1(a1_signed),
            .a2(a2_signed),
            .w1(weight_mem[cycle_counter * 2][i]),
            .w2((cycle_counter * 2 + 1 < VECTOR_LEN) ? weight_mem[cycle_counter * 2 + 1][i] : 8'h00),
            .acc(pe_acc_out[i])
        ); 
    end
endgenerate

// Add biases and apply ReLU after computation is done
reg signed [ACC_WIDTH-1:0] final_results [0:NUM_PES-1];
reg bias_added;

always @(posedge clk) begin
    if (reset) begin
        bias_added <= 0;
        for (integer j = 0; j < NUM_PES; j = j + 1) begin
            final_results[j] <= 0;
        end
    end else if (state_reg == S_DONE && !bias_added) begin
        for (integer j = 0; j < NUM_PES; j = j + 1) begin
            if (pe_acc_out[j] + bias_mem[j] < 0) begin
                final_results[j] <= 0;  // ReLU
            end else begin
                final_results[j] <= pe_acc_out[j] + bias_mem[j];
            end
        end
        bias_added <= 1;
    end else if (state_reg == S_IDLE) begin
        bias_added <= 0;
    end
end

// Pack results into output vector (using genvar for constant slicing)
genvar k;
generate
    for (k = 0; k < NUM_PES; k = k + 1) begin : assign_slices
        assign result_vector[(k+1)*ACC_WIDTH-1 : k*ACC_WIDTH] = final_results[k];
    end
endgenerate

endmodule
