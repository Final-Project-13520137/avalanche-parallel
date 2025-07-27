# Avalanche Medium Transaction Test Case Benchmark

## Summary
- **Date:** 2023-06-15 10:38:20
- **Best Speedup:** 4.40x with 8 threads
- **Transaction Profile:** medium
- **Transaction Count:** 5000
- **Batch Size:** 50

## Detailed Results

| Threads | Parallel Time | Sequential Time | Speedup |
|---------|--------------|----------------|---------|
| 1 | 3.45s | 3.45s | 1.00x |
| 2 | 1.91s | 3.45s | 1.81x |
| 4 | 1.15s | 3.45s | 3.00x |
| 8 | 0.78s | 3.45s | 4.40x | 