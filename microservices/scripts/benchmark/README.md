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

Suite ini menyediakan tools untuk:
1. Benchmarking performa sistem Avalanche Parallel
2. Mempertahankan konfigurasi worker pools saat benchmark
3. Mengukur throughput dan latency pada berbagai skala
4. Membandingkan performa monolith vs microservices

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