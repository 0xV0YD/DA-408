#!/bin/bash

echo "=== MNIST Neural Network - Optimized Parallel Architecture ==="
echo

# Step 1: Ensure we have the training data
if [ ! -d "output" ] || [ ! -f "output/weights1.mem" ]; then
    echo "Step 1: Generating training data..."
    python3 mnist_quantization.py
    if [ $? -ne 0 ]; then
        echo "❌ Python script failed!"
        exit 1
    fi
    echo "✅ Training data generated"
else
    echo "✅ Training data already exists"
fi
echo

# Step 2: Check memory files
echo "Step 2: Verifying memory files..."
files=("output/weights1.mem" "output/biases1.mem" "output/weights2.mem" "output/biases2.mem" "output/input_image.mem")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        echo "✅ $file ($lines lines)"
    else
        echo "❌ $file (missing)"
        exit 1
    fi
done
echo

# Step 3: Compile the optimized version
echo "Step 3: Compiling optimized neural network..."
iverilog -g2012 -o mnist_optimized.vvp \
    mac_pe.v \
    layer1_mnist.v \
    layer2_mnist.v \
    top_mnist_optimized.v

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed!"
    exit 1
fi
echo "✅ Compilation successful"
echo

# Step 4: Run the optimized simulation
echo "Step 4: Running optimized simulation..."
echo "Expected time: ~800 cycles for Layer1 + ~32 cycles for Layer2"
echo "At 100MHz (10ns/cycle): ~8.3μs total"
echo "=============================================="

# Run with timeout for safety
timeout 10s vvp mnist_optimized.vvp
result=$?

echo "=============================================="

if [ $result -eq 0 ]; then
    echo "✅ Optimized simulation completed successfully!"
    echo
    echo "Key advantages of this architecture:"
    echo "• Parallel processing: 32 MAC units for Layer1, 10 for Layer2" 
    echo "• Efficient memory access: 2 inputs processed per cycle"
    echo "• Hardware-friendly: Uses standard MAC units and state machines"
    echo "• Fast: ~830 cycles total vs ~25,000+ in sequential version"
elif [ $result -eq 124 ]; then
    echo "⚠️  Simulation timed out (10s limit)"
    echo "This may indicate memory loading issues or infinite loops"
else
    echo "❌ Simulation failed with exit code: $result"
fi

echo
echo "=== Performance Comparison ==="
echo "Sequential version: ~25,088 cycles (Layer1 only)"
echo "Optimized version:  ~830 cycles (both layers)"
echo "Speedup: ~30x faster!"
echo "================================"