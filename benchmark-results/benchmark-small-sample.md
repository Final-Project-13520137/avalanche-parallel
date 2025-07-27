# Avalanche Small Transaction Test Case Benchmark

## Summary
- **Date:** 2023-06-15 10:35:15
- **Best Speedup:** 4.60x with 8 threads
- **Transaction Profile:** small
- **Transaction Count:** 5000
- **Batch Size:** 50

## Detailed Results

| Threads | Parallel Time | Sequential Time | Speedup |
|---------|--------------|----------------|---------|
| 1 | 2.85s | 2.85s | 1.00x |
| 2 | 1.58s | 2.85s | 1.80x |
| 4 | 0.95s | 2.85s | 3.00x |
| 8 | 0.62s | 2.85s | 4.60x | 