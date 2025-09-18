`timescale 1ns / 1ps

// top_mnist_optimized.v - Top-level testbench using parallel MAC architecture
module top_mnist_optimized;
    // Parameters
    localparam DATA_WIDTH   = 8;
    localparam ACC_WIDTH    = 32;
    
    // Testbench signals
    reg clk;
    reg reset;
    reg start_l1, start_l2;
    wire done_l1, done_l2;
    
    // Inter-layer communication
    wire signed [(ACC_WIDTH * 32)-1:0] layer1_result;
    wire signed [(ACC_WIDTH * 10)-1:0] layer2_result;
    wire [3:0] predicted_class;
    
    // State machine
    reg [2:0] state;
    localparam S_IDLE    = 3'b000;
    localparam S_LAYER1  = 3'b001;
    localparam S_WAIT1   = 3'b010;
    localparam S_LAYER2  = 3'b011;
    localparam S_WAIT2   = 3'b100;
    localparam S_DONE    = 3'b101;
    
    // ✅ Declare loop/indexing vars here
    integer i;  
    reg signed [ACC_WIDTH-1:0] temp_result;
    
    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Instantiate Layer 1
    layer1_mnist #(
        .DATA_WIDTH(DATA_WIDTH),
        .VECTOR_LEN(784),
        .NUM_PES(32),
        .ACC_WIDTH(ACC_WIDTH)
    ) layer1_inst (
        .clk(clk),
        .reset(reset),
        .start(start_l1),
        .done(done_l1),
        .result_vector(layer1_result)
    );
    
    // Instantiate Layer 2
    layer2_mnist #(
        .DATA_WIDTH(DATA_WIDTH),
        .VECTOR_LEN(32),
        .NUM_PES(10),
        .ACC_WIDTH(ACC_WIDTH)
    ) layer2_inst (
        .clk(clk),
        .reset(reset),
        .start(start_l2),
        .input_vector(layer1_result),
        .done(done_l2),
        .result_vector(layer2_result),
        .predicted_class(predicted_class)
    );
    
    // Main control state machine
    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            start_l1 <= 0;
            start_l2 <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    $display("=== Starting MNIST Neural Network (Optimized) ===");
                    state <= S_LAYER1;
                end
                
                S_LAYER1: begin
                    $display("T=%0t: Starting Layer 1 computation...", $time);
                    start_l1 <= 1;
                    state <= S_WAIT1;
                end
                
                S_WAIT1: begin
                    start_l1 <= 0;
                    if (done_l1) begin
                        $display("T=%0t: Layer 1 completed!", $time);
                        state <= S_LAYER2;
                    end
                end
                
                S_LAYER2: begin
                    $display("T=%0t: Starting Layer 2 computation...", $time);
                    start_l2 <= 1;
                    state <= S_WAIT2;
                end
                
                S_WAIT2: begin
                    start_l2 <= 0;
                    if (done_l2) begin
                        $display("T=%0t: Layer 2 completed!", $time);
                        state <= S_DONE;
                    end
                end
                
                S_DONE: begin
                    // Display results
                    $display("\n=== MNIST NEURAL NETWORK RESULTS ===");
                    $display("Raw outputs:");
                    
                    for (i = 0; i < 10; i = i + 1) begin
                        temp_result = layer2_result >> (i * ACC_WIDTH);
                        if (i == predicted_class) begin
                            $display("  Class %d: %10d  <-- PREDICTED", i, temp_result);
                        end else begin
                            $display("  Class %d: %10d", i, temp_result);
                        end
                    end
                    
                    $display("\n*** PREDICTED DIGIT: %d ***", predicted_class);
                    $display("=====================================");
                    
                    $display("\nTotal simulation time: %0t", $time);
                    $finish;
                end

                
                default: begin
                    $display("ERROR: Unknown state %d", state);
                    $finish;
                end
            endcase
        end
    end
    
    // Test sequence
    initial begin
        $display("Initializing MNIST Neural Network (Optimized Architecture)...");
        
        // Initialize
        reset = 1;
        start_l1 = 0;
        start_l2 = 0;
        
        // Release reset
        #50 reset = 0;
        
        // Safety timeout (much more reasonable now)
        #50000 begin
            $display("ERROR: Simulation timeout!");
            $display("Current state: %d", state);
            $display("Layer1 done: %b, Layer2 done: %b", done_l1, done_l2);
            $finish;
        end
    end
    
    // VCD dump for waveform analysis
    initial begin
        $dumpfile("mnist_optimized.vcd");
        $dumpvars(0, top_mnist_optimized);
    end
    
    // Progress monitoring
    always @(posedge clk) begin
        if (!reset) begin
            case (state)
                S_WAIT1: if (layer1_inst.cycle_counter % 50 == 0)
                    $display("Layer1 progress: cycle %d / %d", 
                             layer1_inst.cycle_counter, layer1_inst.CYCLES_NEEDED);
                S_WAIT2: if (layer2_inst.cycle_counter % 5 == 0)
                    $display("Layer2 progress: cycle %d / %d", 
                             layer2_inst.cycle_counter, layer2_inst.CYCLES_NEEDED);
            endcase
        end
    end

endmodule