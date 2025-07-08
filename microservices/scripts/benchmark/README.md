# 🚀 Avalanche Parallel Benchmark Suite

Benchmark suite untuk mengukur performa sistem Avalanche Parallel dengan worker pools yang mendukung scaling preservation.

## 📋 Daftar Isi
- [Overview](#-overview)
- [Fitur](#-fitur)
- [Penggunaan](#-penggunaan)
- [Worker Scaling](#-worker-scaling)
- [Testing](#-testing)
- [Troubleshooting](#-troubleshooting)

## 🔍 Overview

### Actual Benchmark Flow

```
                     BENCHMARK EXECUTION FLOW
                                                                   
┌────────────────────────────────────────────────────────────────┐
│                    BENCHMARK CONTROLLER                        │
│                                                               │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐         │
│  │ Worker      │   │ Test Case   │   │ Metrics     │         │
│  │ Detection   │   │ Generator   │   │ Collector   │         │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘         │
│         │                 │                 │                 │
│         ▼                 ▼                 ▼                 │
│  ┌──────────────────────────────────────────────────┐        │
│  │                TEST EXECUTION                    │        │
│  │                                                  │        │
│  │ ┌────────────┐  ┌────────────┐  ┌────────────┐  │        │
│  │ │ Small Load │  │Medium Load │  │ High Load  │  │        │
│  │ │            │  │            │  │            │  │        │
│  │ │Tx: 1,000   │  │Tx: 5,000   │  │Tx: 10,000  │  │        │
│  │ │Users: 5    │  │Users: 15   │  │Users: 30   │  │        │
│  │ │Size: 256B  │  │Size: 512B  │  │Size: 1KB   │  │        │
│  │ └────────────┘  └────────────┘  └────────────┘  │        │
│  │                                                  │        │
│  │ Metrics Collected:                               │        │
│  │ • Transaction Throughput (TPS)                   │        │
│  │ • Processing Latency (ms)                        │        │
│  │ • Resource Utilization (CPU/Memory)              │        │
│  │ • Error Rates                                    │        │
│  └──────────────────────────────────────────────────┘        │
│                          │                                   │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────┐        │
│  │               RESULTS ANALYSIS                   │        │
│  │                                                  │        │
│  │ ┌────────────┐  ┌────────────┐  ┌────────────┐  │        │
│  │ │Performance │  │ Resource   │  │ Scaling    │  │        │
│  │ │Metrics     │  │ Usage      │  │ Efficiency │  │        │
│  │ │            │  │            │  │            │  │        │
│  │ │• TPS       │  │• CPU %     │  │• Worker    │  │        │
│  │ │• Latency   │  │• Memory %  │  │  Scale     │  │        │
│  │ │• Success % │  │• Network   │  │• Load      │  │        │
│  │ │            │  │  I/O       │  │  Balance   │  │        │
│  │ └────────────┘  └────────────┘  └────────────┘  │        │
│  └──────────────────────────────────────────────────┘        │
│                          │                                   │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────┐        │
│  │               REPORT GENERATION                  │        │
│  │                                                  │        │
│  │ • Performance Summary                            │        │
│  │ • Comparative Analysis                           │        │
│  │ • Resource Utilization Graphs                    │        │
│  │ • Scaling Recommendations                        │        │
│  └──────────────────────────────────────────────────┘        │
└────────────────────────────────────────────────────────────────┘

Test Case Details:
1. Small Load Test:
   • Transactions: 1,000
   • Concurrent Users: 5
   • Transaction Size: 256 bytes
   • Type: Transfer
   • Complexity: Low
   • Duration: 5 minutes

2. Medium Load Test:
   • Transactions: 5,000
   • Concurrent Users: 15
   • Transaction Size: 512 bytes
   • Type: Transfer
   • Complexity: Medium
   • Duration: 15 minutes

3. High Load Test:
   • Transactions: 10,000
   • Concurrent Users: 30
   • Transaction Size: 1,024 bytes
   • Type: Contract
   • Complexity: High
   • Duration: 30 minutes

4. Maximum Load Test:
   • Transactions: 20,000
   • Concurrent Users: 50
   • Transaction Size: 2,048 bytes
   • Type: Contract
   • Complexity: Very High
   • Duration: 60 minutes

Worker Pool Configuration:
1. Validator Workers:
   • Pool Size: 50 goroutines/container
   • Processing Time: 2-10ms/tx
   • Success Rate: 90-95%
   • Scale: 3-15 pods

2. Consensus Workers:
   • Pool Size: 30 goroutines/container
   • Processing Time: 50-150ms/tx
   • Success Rate: 80-85%
   • Scale: 2-10 pods

3. DAG+State Workers:
   • Pool Size: 20 goroutines/container
   • Processing Time: 100-300ms/tx
   • Success Rate: 95-98%
   • Scale: 2-8 pods

Metrics Collection:
• Sampling Rate: 1s
• Aggregation Window: 10s
• Export Format: JSON/CSV
• Graph Generation: PNG/SVG
```

## ✨ Fitur

### Worker Scaling Preservation
- Mempertahankan jumlah worker yang sudah di-scale
- Tidak mereset worker count ke default
- Mendukung custom scaling configuration
- Deteksi otomatis worker yang aktif

### Benchmark Capabilities
- Throughput testing (TPS)
- Latency measurement
- Resource utilization tracking
- Automatic report generation

### Cross-Platform Support
- Linux/macOS: `run-benchmark.sh`
- Windows: `run-benchmark.ps1`
- Docker environment detection
- Kubernetes compatibility

## 🚀 Penggunaan

### Linux/macOS
```bash
# Basic usage (preserves existing worker scale)
./run-benchmark.sh

# Run with specific worker counts (if no workers running)
VALIDATOR_WORKERS=5 CONSENSUS_WORKERS=3 DAG_STATE_WORKERS=2 ./run-benchmark.sh

# Run with cleanup after completion
CLEANUP_AFTER=true ./run-benchmark.sh
```

### Windows PowerShell
```powershell
# Basic usage
.\run-benchmark.ps1

# Run with custom defaults
.\run-benchmark.ps1 -DefaultValidatorWorkers 5 -DefaultConsensusWorkers 3

# Run with cleanup
.\run-benchmark.ps1 -ForceCleanup
```

### Environment Variables
```bash
# Optional configuration
export BENCHMARK_RESULTS_DIR="./results"    # Results directory
export BENCHMARK_GRAPHS_DIR="./graphs"      # Graphs directory
export CLEANUP_AFTER=true                   # Cleanup after benchmark
export PRESERVE_SCALE=true                  # Preserve worker scale (default: true)
```

## 📊 Worker Scaling

### Supported Configurations

```
Worker Type    | Minimum | Maximum | Default
---------------|---------|---------|--------
Validator      | 3       | 15      | 3
Consensus      | 2       | 10      | 2
DAG+State      | 2       | 8       | 2
```

### Scaling Behavior

1. **Existing Workers**
```bash
   # If workers already running:
   - Detects current worker counts
   - Preserves existing scale
   - Uses current configuration
   ```

2. **No Workers Running**
   ```bash
   # If no workers detected:
   - Uses default counts
   - Or uses specified counts
   - Starts fresh configuration
   ```

3. **Mixed State**
   ```bash
   # If some workers running:
   - Preserves running worker counts
   - Uses defaults for missing types
   - Maintains partial configuration
   ```

### Scaling Examples

```bash
# Scale up before benchmark
docker-compose -f docker-compose.worker-pools.yml up -d \
  --scale validator-worker=8 \
  --scale consensus-worker=5 \
  --scale dag-state-worker=3

# Run benchmark (will preserve 8:5:3 configuration)
./run-benchmark.sh

# Scale down after benchmark
docker-compose -f docker-compose.worker-pools.yml up -d \
  --scale validator-worker=4 \
  --scale consensus-worker=3 \
  --scale dag-state-worker=2
```

## 🧪 Testing

### Test Scaling Preservation

```bash
# Run scaling preservation test
./test-scaling-preservation.sh

# Test specific configurations
./test-scaling-preservation.sh --config minimal  # Tests 3:2:2
./test-scaling-preservation.sh --config maximal  # Tests 15:10:8
./test-scaling-preservation.sh --config custom   # Tests 8:5:3
```

### Verify Worker Counts

```bash
# Check current worker counts
./get-worker-count.sh

# Check specific worker type
./get-worker-count.sh validator
./get-worker-count.sh consensus
./get-worker-count.sh dag-state
```

## 🧪 Mekanisme Percobaan Detail

### Test Matrix

```
                     BENCHMARK TEST MATRIX
                                                                   
┌────────────────────────────────────────────────────────────────┐
│                    TEST CONFIGURATIONS                         │
│                                                               │
│  1. TRANSACTION TYPES                                         │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐         │
│  │ Transfer    │   │ Contract    │   │ Mixed       │         │
│  │ Transaction │   │ Execution   │   │ Workload    │         │
│  │ • Simple    │   │ • Deploy    │   │ • 60% Trans │         │
│  │ • Multi-sig │   │ • Call      │   │ • 30% Call  │         │
│  │ • Batch     │   │ • Complex   │   │ • 10% Deploy│         │
│  └─────────────┘   └─────────────┘   └─────────────┘         │
│                                                               │
│  2. BATCH SIZES                                               │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐         │
│  │ Small       │   │ Medium      │   │ Large       │         │
│  │ • 100 tx    │   │ • 500 tx    │   │ • 1000 tx   │         │
│  │ • 5 users   │   │ • 15 users  │   │ • 30 users  │         │
│  └─────────────┘   └─────────────┘   └─────────────┘         │
│                                                               │
│  3. WORKER CONFIGURATIONS                                     │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐         │
│  │ Minimal     │   │ Balanced    │   │ Maximum     │         │
│  │ • Val: 3    │   │ • Val: 8    │   │ • Val: 15   │         │
│  │ • Con: 2    │   │ • Con: 5    │   │ • Con: 10   │         │
│  │ • DAG: 2    │   │ • DAG: 4    │   │ • DAG: 8    │         │
│  └─────────────┘   └─────────────┘   └─────────────┘         │
└────────────────────────────────────────────────────────────────┘

Test Iterations: 5x per configuration
Total Test Cases: 81 (3x3x3x3 configurations x 5 iterations)
```

### Skenario Pengujian

1. **Transfer Transaction Tests**
   ```
   Batch Sizes: [100, 500, 1000] tx
   Iterations per batch: 5
   Transaction Types:
   • Simple Transfer (1-to-1)
     - Size: 256 bytes
     - Validation: 2ms
     - Success Rate: 95%
   
   • Multi-signature (2-of-3)
     - Size: 512 bytes
     - Validation: 5ms
     - Success Rate: 90%
   
   • Batch Transfer (1-to-many)
     - Size: 1024 bytes
     - Validation: 8ms
     - Success Rate: 85%
   ```

2. **Smart Contract Tests**
   ```
   Batch Sizes: [100, 500, 1000] tx
   Iterations per batch: 5
   Contract Types:
   • Deploy Contract
     - Size: 2048 bytes
     - Validation: 10ms
     - Success Rate: 80%
   
   • Contract Call
     - Size: 512 bytes
     - Validation: 3ms
     - Success Rate: 90%
   
   • Complex Contract (with loops)
     - Size: 4096 bytes
     - Validation: 15ms
     - Success Rate: 75%
   ```

3. **Mixed Workload Tests**
   ```
   Batch Sizes: [100, 500, 1000] tx
   Iterations per batch: 5
   Transaction Mix:
   • 60% Simple Transfers
   • 30% Contract Calls
   • 10% Contract Deployments
   
   Load Distribution:
   • Uniform: Even distribution
   • Burst: Spike every 30s
   • Wave: Sinusoidal pattern
   ```

### Pengukuran Metrik

1. **Performance Metrics**
   ```
   Throughput:
   • Transactions per second (TPS)
   • Sampling: Every 1s
   • Aggregation: 10s window
   • Export: CSV format
   
   Latency:
   • End-to-end processing time
   • Per-worker processing time
   • Queue waiting time
   • Network transmission time
   
   Success Rate:
   • Transaction success/failure
   • Error categorization
   • Retry statistics
   ```

2. **Resource Utilization**
   ```
   CPU Usage:
   • Per worker monitoring
   • 1s sampling rate
   • Peak/Average tracking
   
   Memory Usage:
   • Heap allocation
   • GC statistics
   • Memory growth patterns
   
   Network I/O:
   • Inter-worker communication
   • Queue message volume
   • Network latency
   ```

3. **Scaling Metrics**
   ```
   Worker Scaling:
   • Scale-up triggers
   • Scale-down patterns
   • Stabilization periods
   
   Load Distribution:
   • Worker load balance
   • Queue depth per worker
   • Processing skew
   ```

### Prosedur Pengujian

1. **Persiapan Environment**
   ```bash
   # 1. Reset environment
   ./scripts/benchmark/reset-environment.sh
   
   # 2. Deploy worker pools
   ./scripts/benchmark/deploy-workers.sh \
     --validator-count $val \
     --consensus-count $con \
     --dag-state-count $dag
   
   # 3. Warm up system
   ./scripts/benchmark/warmup.sh --duration 5m
   ```

2. **Eksekusi Test**
   ```bash
   # For each configuration:
   for batch_size in 100 500 1000; do
     for worker_config in minimal balanced maximum; do
       for tx_type in transfer contract mixed; do
         for iteration in {1..5}; do
           # Run benchmark
           ./scripts/benchmark/run-test.sh \
             --type $tx_type \
             --batch-size $batch_size \
             --worker-config $worker_config \
             --iteration $iteration
           
           # Cool down period
           sleep 2m
           
           # Collect metrics
           ./scripts/benchmark/collect-metrics.sh \
             --test-id "${tx_type}_${batch_size}_${worker_config}_${iteration}"
         done
       done
     done
   done
   ```

3. **Analisis Hasil**
   ```bash
   # Generate reports
   ./scripts/benchmark/analyze-results.sh \
     --input-dir benchmark-results/ \
     --output-format html,csv \
     --generate-graphs true
   
   # Compare configurations
   ./scripts/benchmark/compare-configs.sh \
     --baseline minimal \
     --compare-with balanced,maximum
   
   # Generate recommendations
   ./scripts/benchmark/generate-recommendations.sh \
     --based-on-results true
   ```

### Validasi & Verifikasi

1. **Data Validation**
   ```
   • Outlier detection
   • Statistical significance
   • Error margin calculation
   • Confidence intervals
   ```

2. **Result Verification**
   ```
   • Cross-validation between runs
   • Consistency checking
   • Performance regression detection
   • Resource usage correlation
   ```

3. **Report Generation**
   ```
   • Performance summaries
   • Comparative analysis
   • Scaling efficiency
   • Resource utilization
   • Recommendations
   ```

## 🔧 Troubleshooting

### Common Issues

1. **Workers Not Preserved**
```bash
   # Check if services are running
   docker-compose ps

   # Verify worker detection
   ./get-worker-count.sh

   # Force preserve scale
   export PRESERVE_SCALE=true
```

2. **Incorrect Worker Counts**
```bash
   # Clean up stale containers
   docker-compose down
   
   # Start fresh with specific scale
   docker-compose up -d --scale validator-worker=5
   ```

3. **Benchmark Failures**
```bash
   # Enable debug logging
   export LOG_LEVEL=debug
   
   # Run with verbose output
   ./run-benchmark.sh --verbose
```

### Debug Tools

```bash
# Show current configuration
./get-worker-count.sh --verbose

# Test scaling preservation
./test-scaling-preservation.sh --debug

# Monitor worker status
watch -n 1 ./get-worker-count.sh
```

## 📊 Results

Benchmark results akan disimpan di:
- `benchmark-results/`: Raw data dan metrics
- `benchmark-graphs/`: Generated visualizations
- `benchmark-reports/`: Analysis reports

### Example Output
```
📊 Worker Pool Status:
  - Validator Workers: 8 (preserved from 8)
  - Consensus Workers: 5 (preserved from 5)
  - DAG+State Workers: 3 (preserved from 3)
  - Total Active Workers: 16

🔍 Performance Metrics:
  - Throughput: 25,000 TPS
  - Avg Latency: 45ms
  - Error Rate: 0.01%
  - CPU Usage: 75%
```

## 🤝 Contributing

1. Fork repository
2. Create feature branch
3. Add/modify tests
4. Submit pull request

## 📝 License

MIT License - see LICENSE file for details

## 📞 Support

Untuk pertanyaan atau issues:
1. Check troubleshooting section
2. Review worker logs dan metrics
3. Create GitHub issue dengan detail lengkap
4. Include system information dan error messages

## Prerequisites

Before running the benchmark, make sure you have:
1. Docker installed and running
2. Kubernetes cluster (minikube) installed
3. Python 3.7+ with required packages (see requirements.txt)
4. Go 1.16+ installed

## Setup Minikube

To setup minikube, run:

```bash
# Download minikube binary
./download-minikube.sh

# Start minikube
./minikube-linux-amd64 start
```

---

**Happy Benchmarking! 🚀** 