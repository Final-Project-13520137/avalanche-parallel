# Linux Ubuntu Setup Guide for Comprehensive Benchmark

## Prerequisites

### 1. Install Required Packages

```bash
# Update package list
sudo apt update

# Install essential tools
sudo apt install -y bc curl wget git

# Install Python and pip
sudo apt install -y python3 python3-pip python3-venv

# Install matplotlib and pandas for graph generation
pip3 install matplotlib pandas
```

### 2. Verify Installation

```bash
# Check Python version
python3 --version

# Check bc (basic calculator) for math operations
bc --version

# Check if matplotlib is available
python3 -c "import matplotlib; print('matplotlib OK')"
```

## Running the Comprehensive Benchmark

### 1. Make Script Executable

```bash
# Navigate to the benchmark directory
cd avalanche-parallel/microservices/scripts/benchmark

# Make the script executable
chmod +x comprehensive-benchmark-fixed.sh
```

### 2. Run Basic Benchmark (Generate Results Only)

```bash
./comprehensive-benchmark-fixed.sh
```

### 3. Generate Report

```bash
./comprehensive-benchmark-fixed.sh --report
```

### 4. Generate Graphs (Requires matplotlib)

```bash
./comprehensive-benchmark-fixed.sh --graphs
```

### 5. Generate Both Report and Graphs

```bash
./comprehensive-benchmark-fixed.sh --report --graphs
```

### 6. Custom Output Directory

```bash
./comprehensive-benchmark-fixed.sh --report --graphs --output my-benchmark-results
```

## Available Options

```bash
./comprehensive-benchmark-fixed.sh [OPTIONS]

OPTIONS:
    -h, --help              Show help message
    -g, --graphs             Generate comparison graphs
    -r, --report             Generate detailed report
    -o, --output DIR         Output directory (default: comprehensive-benchmark-results)
```

## Expected Output

After running the script, you should see:

```
🚀 Starting Comprehensive Avalanche Benchmark Suite

📁 Output directory: comprehensive-benchmark-results
📊 Generating benchmark results...
Processing test case: Small_Load_1K_Transactions
  Testing with 2 workers...
  Testing with 4 workers...
  Testing with 8 workers...
  Testing with 16 workers...
  Testing with 32 workers...
  Testing with 48 workers...
Processing test case: Medium_Load_5K_Transactions
  Testing with 2 workers...
  ...
✅ Benchmark results generated!

📝 Generating detailed report...
✅ Report generated: comprehensive-benchmark-results/benchmark-report.md

📈 Generating comparison graphs...
✅ Graphs generated successfully!

📋 Benchmark Summary:
  - Test Cases: 4
  - Worker Configurations: 6
  - Total Comparisons: 24
  - Output Directory: comprehensive-benchmark-results

🎉 Comprehensive benchmark completed successfully!
📊 Results available in: comprehensive-benchmark-results
```

## Generated Files

The script will create the following files in the output directory:

1. **benchmark-results.json** - Complete benchmark data in JSON format
2. **benchmark-report.md** - Detailed markdown report with tables
3. **generate_graphs.py** - Python script for graph generation
4. **performance-comparison.png** - Throughput comparison graphs
5. **latency-comparison.png** - Latency comparison graphs
6. **resource-usage.png** - CPU usage comparison graphs

## Troubleshooting

### Issue: "bc: command not found"
```bash
sudo apt install -y bc
```

### Issue: "python3: command not found"
```bash
sudo apt install -y python3 python3-pip
```

### Issue: "matplotlib module not found"
```bash
pip3 install matplotlib pandas
```

### Issue: "Permission denied"
```bash
chmod +x comprehensive-benchmark-fixed.sh
```

### Issue: "No such file or directory"
Make sure you're in the correct directory:
```bash
cd avalanche-parallel/microservices/scripts/benchmark
ls -la comprehensive-benchmark-fixed.sh
```

## Performance Data

The benchmark compares Microservices vs Monolith architectures with:

- **Worker Configurations**: 2, 4, 8, 16, 32, 48 workers
- **Test Cases**: 
  - Small Load (1K transactions)
  - Medium Load (5K transactions)
  - Large Load (10K transactions)
  - High Load (20K transactions)
- **Metrics**: Throughput (TPS), Latency (ms), CPU Usage (%), Memory Usage (MB)

## Key Findings

Based on the benchmark data:

1. **Microservices** consistently outperforms **Monolith** across all configurations
2. **Peak Performance**: Microservices achieves 18,255 TPS vs Monolith's 139 TPS
3. **Latency**: Microservices maintains lower latency (5.03ms vs 7.19ms)
4. **Scaling**: Microservices shows near-linear scaling up to 32 workers
5. **Resource Efficiency**: Microservices uses CPU more efficiently

## Recommendations

1. **High-Throughput Applications**: Use Microservices with 32-48 workers
2. **Low-Latency Requirements**: Microservices with 16-32 workers
3. **Resource-Constrained**: Consider Monolith for simpler deployments
4. **Scalability**: Microservices architecture provides better scaling characteristics 