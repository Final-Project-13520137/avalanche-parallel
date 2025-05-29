# Avalanche Large Transaction Test Case Benchmark

## Summary
- **Date:** 2023-06-15 10:40:30
- **Best Speedup:** 3.70x with 8 threads
- **Transaction Profile:** large
- **Transaction Count:** 5000
- **Batch Size:** 50

## Detailed Results

| Threads | Parallel Time | Sequential Time | Speedup |
|---------|--------------|----------------|---------|
| 1 | 4.21s | 4.21s | 1.00x |
| 2 | 2.34s | 4.21s | 1.80x |
| 4 | 1.68s | 4.21s | 2.51x |
| 8 | 1.13s | 4.21s | 3.70x | 