# Comprehensive Avalanche Benchmark Suite

## Overview

This comprehensive benchmark suite compares **Microservices vs Monolith** architectures across different worker configurations (2, 4, 8, 16, 32, 48 workers) based on real benchmark data from Avalanche performance tests.

## 📁 Available Scripts

### 1. PowerShell Scripts (Windows)
- `comprehensive-benchmark-fixed.ps1` - **Main script** (Fixed version)
- `comprehensive-benchmark.ps1` - Original version (has syntax issues)

### 2. Bash Scripts (Linux/Ubuntu)
- `comprehensive-benchmark-fixed.sh` - **Main script** (Fixed version)
- `comprehensive-benchmark.sh` - Original version

### 3. Test & Setup Scripts
- `test-linux-compatibility.sh` - Test Linux environment compatibility
- `LINUX-UBUNTU-SETUP.md` - Detailed Linux Ubuntu setup guide

## 🚀 Quick Start

### Windows (PowerShell)
```powershell
# Navigate to benchmark directory
cd avalanche-parallel/microservices/scripts/benchmark

# Run with report and graphs
.\comprehensive-benchmark-fixed.ps1 -GenerateReport -GenerateGraphs

# Run with report only
.\comprehensive-benchmark-fixed.ps1 -GenerateReport

# Run with graphs only (requires Python + matplotlib)
.\comprehensive-benchmark-fixed.ps1 -GenerateGraphs
```

### Linux Ubuntu
```bash
# Navigate to benchmark directory
cd avalanche-parallel/microservices/scripts/benchmark

# Make script executable
chmod +x comprehensive-benchmark-fixed.sh

# Test compatibility first
./test-linux-compatibility.sh

# Run with report and graphs
./comprehensive-benchmark-fixed.sh --report --graphs

# Run with report only
./comprehensive-benchmark-fixed.sh --report

# Run with graphs only (requires matplotlib)
./comprehensive-benchmark-fixed.sh --graphs
```

## 📊 Benchmark Data

The scripts use real benchmark data from Avalanche performance tests:

### Test Cases
1. **Small Load (1K Transactions)**
2. **Medium Load (5K Transactions)**
3. **Large Load (10K Transactions)**
4. **High Load (20K Transactions)**

### Worker Configurations
- 2, 4, 8, 16, 32, 48 workers

### Metrics Measured
- **Throughput (TPS)** - Transactions per second
- **Latency (ms)** - Response time in milliseconds
- **CPU Usage (%)** - CPU utilization percentage
- **Memory Usage (MB)** - Memory consumption in megabytes

## 🎯 Key Findings

### Performance Comparison
| Metric | Microservices | Monolith | Improvement |
|--------|---------------|----------|-------------|
| **Peak Throughput** | 18,255 TPS | 139 TPS | **13,027%** |
| **Best Latency** | 5.03ms | 7.19ms | **30% faster** |
| **CPU Efficiency** | Better scaling | Saturation at low workers | **More efficient** |
| **Memory Usage** | Higher but scales better | Lower but limited scaling | **Better scaling** |

### Scaling Characteristics
- **Microservices**: Near-linear scaling up to 32 workers
- **Monolith**: Performance plateaus early due to single-threaded bottlenecks
- **Optimal Configuration**: Microservices with 32-48 workers

## 📈 Generated Output

### Files Created
1. **benchmark-results.json** - Complete data in JSON format
2. **benchmark-report.md** - Detailed markdown report with tables
3. **generate_graphs.py** - Python script for graph generation
4. **performance-comparison.png** - Throughput comparison graphs
5. **latency-comparison.png** - Latency comparison graphs
6. **resource-usage.png** - CPU usage comparison graphs

### Sample Report Structure
```markdown
# Comprehensive Avalanche Benchmark Report

## Executive Summary
- Worker Configurations: 2, 4, 8, 16, 32, 48 workers
- Test Cases: Small Load (1K), Medium Load (5K), Large Load (10K), High Load (20K)
- Metrics: Throughput (TPS), Latency (ms), CPU Usage (%), Memory Usage (MB)

## Detailed Results
| Workers | Architecture | Throughput (TPS) | Latency (ms) | CPU (%) | Memory (MB) |
|---------|--------------|------------------|--------------|---------|-------------|
| 48 | Microservices | 18255.82 | 5.03 | 100 | 8136 |
| 48 | Monolith | 139.03 | 7.19 | 100 | 4406.4 |

## Performance Analysis
- Microservices consistently outperforms Monolith
- Scaling benefits become more pronounced with higher worker counts
- Peak performance achieved with 48 workers in Microservices architecture
```

## 🔧 Prerequisites

### Windows Requirements
- PowerShell 5.1 or higher
- Python 3.x (for graphs)
- matplotlib, pandas (for graphs)

### Linux Ubuntu Requirements
```bash
# Install required packages
sudo apt update
sudo apt install -y bc python3 python3-pip
pip3 install matplotlib pandas

# Verify installation
./test-linux-compatibility.sh
```

## 🛠️ Troubleshooting

### Common Issues

#### PowerShell Issues
```powershell
# Error: "The term '...' is not recognized"
# Solution: Make sure you're in the correct directory
cd avalanche-parallel/microservices/scripts/benchmark

# Error: "matplotlib module not found"
# Solution: Install Python packages
pip install matplotlib pandas
```

#### Linux Issues
```bash
# Error: "bc: command not found"
sudo apt install -y bc

# Error: "Permission denied"
chmod +x comprehensive-benchmark-fixed.sh

# Error: "matplotlib module not found"
pip3 install matplotlib pandas
```

### Test Compatibility
```bash
# Test Linux environment
./test-linux-compatibility.sh

# Check script syntax
bash -n comprehensive-benchmark-fixed.sh
```

## 📋 Command Options

### PowerShell Options
```powershell
.\comprehensive-benchmark-fixed.ps1 [OPTIONS]

OPTIONS:
    -Help              Show help message
    -GenerateGraphs    Generate comparison graphs
    -GenerateReport    Generate detailed report
    -OutputDir DIR     Output directory (default: comprehensive-benchmark-results)
```

### Bash Options
```bash
./comprehensive-benchmark-fixed.sh [OPTIONS]

OPTIONS:
    -h, --help              Show help message
    -g, --graphs             Generate comparison graphs
    -r, --report             Generate detailed report
    -o, --output DIR         Output directory (default: comprehensive-benchmark-results)
```

## 🎯 Recommendations

Based on benchmark results:

1. **For High-Throughput Applications**: Use Microservices with 32-48 workers
2. **For Low-Latency Requirements**: Microservices with 16-32 workers
3. **For Resource-Constrained Environments**: Consider Monolith for simpler deployments
4. **For Scalability**: Microservices architecture provides better scaling characteristics

## 📚 Additional Resources

- `LINUX-UBUNTU-SETUP.md` - Detailed Linux setup guide
- `test-linux-compatibility.sh` - Environment compatibility test
- `comprehensive-benchmark-results/` - Sample output directory

## 🔄 Version History

- **v1.0** - Initial release with basic benchmark functionality
- **v1.1** - Fixed PowerShell syntax issues
- **v1.2** - Added Linux Ubuntu compatibility
- **v1.3** - Enhanced error handling and compatibility testing

## 🤝 Contributing

To improve the benchmark suite:

1. Test on different environments
2. Add new test cases
3. Enhance graph generation
4. Improve error handling
5. Add more detailed analysis

## 📄 License

This benchmark suite is part of the Avalanche Parallel project and follows the same licensing terms. 