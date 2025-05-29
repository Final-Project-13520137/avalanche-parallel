# Avalanche Parallel vs Traditional Consensus Benchmark

## Summary
- **Date:** 2023-06-15 10:30:45
- **Best Speedup:** 4.42x with 8 threads
- **Transaction Profile:** mixed
- **Transaction Count:** 5000
- **Batch Size:** 50

## Detailed Results

| Threads | Parallel Time | Sequential Time | Speedup |
|---------|--------------|----------------|---------|
| 2 | 1.91s | 3.45s | 1.81x |
| 4 | 1.15s | 3.45s | 3.00x |
| 8 | 0.78s | 3.45s | 4.42x |
| 16 | 0.65s | 3.45s | 5.31x | 