#!/usr/bin/env python3

import torch
import time

def benchmark_operation(func, *args, num_iterations=100, warmup=10):
    """Benchmark a PyTorch operation"""
    # Warmup
    for _ in range(warmup):
        func(*args)
    
    # Synchronize GPU if available
    if torch.cuda.is_available():
        torch.cuda.synchronize()
    
    # Benchmark
    start_time = time.perf_counter()
    for _ in range(num_iterations):
        func(*args)
    
    if torch.cuda.is_available():
        torch.cuda.synchronize()
    
    end_time = time.perf_counter()
    avg_time = (end_time - start_time) / num_iterations * 1000  # Convert to ms
    
    return avg_time

def main():
    # Check device
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Running benchmarks on: {device}")
    print("-" * 60)
    
    # Small matrices for quick execution
    size = 512
    A = torch.randn(size, size, device=device)
    B = torch.randn(size, size, device=device)
    v = torch.randn(size, device=device)
    
    # Benchmark operations
    operations = {
        'Matrix Multiplication': lambda: torch.mm(A, B),
        'Element-wise Multiply': lambda: A * B,
        'Matrix-Vector Multiply': lambda: torch.mv(A, v),
        'Sum': lambda: A.sum(),
        'ReLU': lambda: torch.relu(A),
        'Softmax': lambda: torch.softmax(A, dim=1),
    }
    
    results = {}
    for name, op in operations.items():
        avg_time = benchmark_operation(op, num_iterations=100)
        results[name] = avg_time
        print(f"{name:25s}: {avg_time:8.4f} ms")
    
    print("-" * 60)
    print(f"Total benchmark time: ~{sum(results.values()):.2f} ms")

if __name__ == "__main__":
    main()
