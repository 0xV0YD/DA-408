// simple_nn_test.v - Fast computation version for immediate results
module simple_nn_test;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter IN_SIZE = 784;
    parameter HIDDEN_SIZE = 32;
    parameter OUT_SIZE = 10;

    // Memory arrays
    reg signed [DATA_WIDTH-1:0] weights1[0:IN_SIZE*HIDDEN_SIZE-1];
    reg signed [DATA_WIDTH-1:0] biases1[0:HIDDEN_SIZE-1];
    reg signed [DATA_WIDTH-1:0] weights2[0:HIDDEN_SIZE*OUT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] biases2[0:OUT_SIZE-1];
    reg [DATA_WIDTH-1:0] input_image[0:IN_SIZE-1];
    
    // Layer outputs
    reg signed [ACC_WIDTH-1:0] layer1_out[0:HIDDEN_SIZE-1];
    reg signed [ACC_WIDTH-1:0] layer2_out[0:OUT_SIZE-1];
    
    // Computation variables
    reg signed [ACC_WIDTH-1:0] accumulator;
    reg signed [ACC_WIDTH-1:0] max_val;
    reg [3:0] predicted_digit;
    integer i, j;
    
    initial begin
        $display("=== MNIST Neural Network - Fast Computation Test ===");
        $display("Loading memory files from output/ directory...");
        
        // Load all memory files
        $readmemh("output/weights1.mem", weights1);
        $readmemh("output/biases1.mem", biases1);  
        $readmemh("output/weights2.mem", weights2);
        $readmemh("output/biases2.mem", biases2);
        $readmemh("output/input_image.mem", input_image);
        
        $display("✓ All memory files loaded successfully");
        $display("");
        
        // Verify some data was loaded
        $display("Sample data verification:");
        $display("  First input pixel: %02x (%d)", input_image[0], input_image[0]);
        $display("  First weight1: %02x (%d)", weights1[0], $signed(weights1[0]));
        $display("  First bias1: %02x (%d)", biases1[0], $signed(biases1[0]));
        $display("");
        
        $display("Starting Layer 1 computation (784 inputs -> 32 outputs)...");
        
        // Layer 1: Fully connected with ReLU
        for (j = 0; j < HIDDEN_SIZE; j = j + 1) begin
            // Start with bias
            accumulator = $signed(biases1[j]);
            
            // Add weighted inputs
            for (i = 0; i < IN_SIZE; i = i + 1) begin
                accumulator = accumulator + 
                             ($signed({1'b0, input_image[i]}) * 
                              $signed(weights1[j * IN_SIZE + i]));
            end
            
            // Apply ReLU activation
            if (accumulator < 0)
                layer1_out[j] = 0;
            else
                layer1_out[j] = accumulator;
                
            // Show progress for first few and last few neurons
            if (j < 3 || j >= HIDDEN_SIZE-3) begin
                $display("  Layer1[%2d] = %8d (before ReLU: %8d)", 
                         j, layer1_out[j], accumulator);
            end else if (j == 3) begin
                $display("  ... (computing middle neurons) ...");
            end
        end
        
        $display("✓ Layer 1 computation complete!");
        $display("");
        
        $display("Starting Layer 2 computation (32 inputs -> 10 outputs)...");
        
        // Layer 2: Fully connected (no activation)
        for (j = 0; j < OUT_SIZE; j = j + 1) begin
            // Start with bias
            accumulator = $signed(biases2[j]);
            
            // Add weighted inputs from layer 1
            for (i = 0; i < HIDDEN_SIZE; i = i + 1) begin
                accumulator = accumulator + 
                             (layer1_out[i] * 
                              $signed(weights2[j * HIDDEN_SIZE + i]));
            end
            
            layer2_out[j] = accumulator;
            $display("  Layer2[%d] = %10d", j, layer2_out[j]);
        end
        
        $display("✓ Layer 2 computation complete!");
        $display("");
        
        // Find the class with maximum output (prediction)
        max_val = layer2_out[0];
        predicted_digit = 0;
        
        for (i = 1; i < OUT_SIZE; i = i + 1) begin
            if (layer2_out[i] > max_val) begin
                max_val = layer2_out[i];
                predicted_digit = i;
            end
        end
        
        $display("=== NEURAL NETWORK RESULTS ===");
        $display("");
        $display("Raw output values:");
        for (i = 0; i < OUT_SIZE; i = i + 1) begin
            if (i == predicted_digit)
                $display("  Class %d: %10d  <-- MAXIMUM", i, layer2_out[i]);
            else
                $display("  Class %d: %10d", i, layer2_out[i]);
        end
        
        $display("");
        $display("*** PREDICTED DIGIT: %d ***", predicted_digit);
        $display("    Maximum value: %d", max_val);
        $display("");
        $display("===============================");
        
        $display("");
        $display("Neural network inference completed successfully!");
        $display("You can compare this with the Python model output.");
        
        $finish;
    end
    
endmodule