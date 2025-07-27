# Worker Variations Benchmark Guide

Panduan lengkap untuk menjalankan dan menganalisis benchmark dengan berbagai konfigurasi worker nodes.

## 📋 Overview

Sistem benchmark sekarang mendukung **automatic worker variations** yang menguji performa sistem dengan berbagai konfigurasi worker untuk setiap test case scenario.

## 🔧 Worker Configurations Tested

### Base Scenarios
1. **Small Load (1K Transactions)**
   - 1,000 transactions, 10 concurrent users
   - Transaction size: 256 bytes
   - Type: Transfer
   - Complexity: Low

2. **Medium Load (5K Transactions)**
   - 5,000 transactions, 25 concurrent users
   - Transaction size: 512 bytes
   - Type: Transfer
   - Complexity: Medium

3. **Large Load (10K Transactions)**
   - 10,000 transactions, 50 concurrent users
   - Transaction size: 1,024 bytes
   - Type: Contract
   - Complexity: High

4. **High Load (20K Transactions)**
   - 20,000 transactions, 100 concurrent users
   - Transaction size: 2,048 bytes
   - Type: Contract
   - Complexity: Very High

### Worker Configurations per Scenario

Setiap scenario dijalankan dengan 3 konfigurasi worker yang berbeda:

#### 1. Minimal Configuration
```
Validator Workers: 1
Consensus Workers: 1
DAG State Workers: 1
Total Workers: 3
```

#### 2. Small Configuration
```
Validator Workers: 3
Consensus Workers: 2
DAG State Workers: 2
Total Workers: 7
```

#### 3. Medium Configuration
```
Validator Workers: 6
Consensus Workers: 4
DAG State Workers: 3
Total Workers: 13
```

## 🎯 Total Test Matrix

```
Test Matrix: 4 scenarios × 3 worker configs = 12 test combinations

Small_Load_1K_Transactions_Workers_1_1_1
Small_Load_1K_Transactions_Workers_3_2_2
Small_Load_1K_Transactions_Workers_6_4_3
Medium_Load_5K_Transactions_Workers_1_1_1
Medium_Load_5K_Transactions_Workers_3_2_2
Medium_Load_5K_Transactions_Workers_6_4_3
Large_Load_10K_Transactions_Workers_1_1_1
Large_Load_10K_Transactions_Workers_3_2_2
Large_Load_10K_Transactions_Workers_6_4_3
High_Load_20K_Transactions_Workers_1_1_1
High_Load_20K_Transactions_Workers_3_2_2
High_Load_20K_Transactions_Workers_6_4_3
```

## 🚀 Running Worker Variation Tests

### Automatic Execution
```bash
# Simply run the benchmark - worker variations are now automatic
./run-benchmark.sh
```

The system will automatically:
1. **Scale workers** for each test case
2. **Wait for readiness** before running tests
3. **Collect metrics** for each configuration
4. **Generate analysis** after all tests complete

### Expected Output
```
📊 Worker Configurations to be tested:
1. Minimal:  1 Validator, 1 Consensus, 1 DAG+State (3 total)
2. Small:    3 Validator, 2 Consensus, 2 DAG+State (7 total)
3. Medium:   6 Validator, 4 Consensus, 3 DAG+State (13 total)
Total test combinations: 4 scenarios × 3 worker configs = 12 test cases
```

### Manual Configuration Override
```bash
# Override specific worker configuration
export VALIDATOR_WORKERS=5
export CONSENSUS_WORKERS=3
export DAG_STATE_WORKERS=2
./run-benchmark.sh
```

## 📊 Analysis & Reports

### Generated Analysis Files

1. **worker_variation_analysis.png**
   - Throughput scaling by scenario
   - Latency vs worker count
   - CPU efficiency patterns
   - Validator worker impact
   - Scaling efficiency scatter plot
   - Worker configuration heatmap

2. **worker_configuration_table.png**
   - Performance comparison table
   - Speedup factors
   - Latency improvements
   - CPU efficiency gains

3. **worker_variation_report.md**
   - Executive summary
   - Best/worst configurations
   - Worker impact analysis
   - Scaling patterns
   - Recommendations

### Key Metrics Analyzed

#### Performance Metrics
- **Throughput (TPS)**: Transactions per second
- **Latency**: Average and P95 response times
- **Error Rate**: Success/failure ratios

#### Resource Metrics
- **CPU Usage**: Per worker and total system
- **Memory Usage**: Allocation and growth patterns
- **Network I/O**: Inter-worker communication

#### Scaling Metrics
- **Efficiency**: TPS per worker
- **Speedup Factor**: vs monolith baseline
- **Resource Utilization**: CPU/Memory efficiency

## 🔍 Understanding Results

### Scaling Patterns

**Linear Scaling**: 
- Performance increases proportionally with workers
- Indicates good parallelization
- Optimal resource utilization

**Diminishing Returns**:
- Performance improvement slows with more workers
- May indicate bottlenecks or contention
- Need for optimization

**Super-linear Scaling**:
- Performance increases more than proportionally
- Often due to better cache utilization
- Good architecture benefits

### Efficiency Analysis

**High Efficiency Indicators**:
- TPS/worker ratio > 1000
- CPU usage 70-80%
- Low latency with high throughput

**Performance Bottlenecks**:
- CPU usage > 90%
- Memory growth patterns
- High error rates

## 🎯 Worker Configuration Guidelines

### Validator Workers (Transaction Processing)
- **Light Load**: 1-3 workers sufficient
- **Medium Load**: 3-6 workers optimal  
- **Heavy Load**: 6-15 workers recommended
- **Characteristics**: CPU-intensive, fast processing

### Consensus Workers (Voting & Finality)
- **Light Load**: 1-2 workers sufficient
- **Medium Load**: 2-4 workers optimal
- **Heavy Load**: 4-10 workers recommended  
- **Characteristics**: Network-intensive, longer processing

### DAG State Workers (State Management)
- **Light Load**: 1-2 workers sufficient
- **Medium Load**: 2-3 workers optimal
- **Heavy Load**: 3-8 workers recommended
- **Characteristics**: Memory-intensive, persistence operations

## 📈 Performance Optimization Tips

### Scaling Strategy
1. **Start Small**: Begin with minimal configuration
2. **Identify Bottlenecks**: Monitor which worker type is saturated
3. **Scale Gradually**: Increase workers incrementally
4. **Monitor Efficiency**: Watch TPS/worker ratios

### Resource Optimization
1. **CPU Optimization**: Target 70-80% utilization
2. **Memory Management**: Monitor for memory leaks
3. **Network Tuning**: Optimize inter-worker communication
4. **Storage Performance**: Use fast storage for state workers

### Configuration Examples

**Development Environment**:
```
Validator: 3 workers
Consensus: 2 workers  
DAG State: 2 workers
Total: 7 workers
```

**Production Environment**:
```
Validator: 10 workers
Consensus: 6 workers
DAG State: 4 workers  
Total: 20 workers
```

**High-Throughput Environment**:
```
Validator: 15 workers
Consensus: 10 workers
DAG State: 8 workers
Total: 33 workers
```

## 🔧 Troubleshooting

### Common Issues

#### Workers Not Scaling
```bash
# Check Docker service status
docker-compose ps

# Verify scaling command
docker-compose logs validator-worker

# Manual scaling
docker-compose -f docker-compose.worker-pools.yml up -d \
  --scale validator-worker=6 \
  --scale consensus-worker=4 \
  --scale dag-state-worker=3
```

#### Performance Inconsistencies
```bash
# Clear system state
docker-compose down
docker system prune -f

# Restart with specific configuration
./run-benchmark.sh
```

#### Analysis Errors
```bash
# Install Python dependencies
pip3 install -r requirements.txt

# Run analysis manually
python3 analyze_worker_variations.py benchmark-results/ worker-analysis/
```

### Debug Commands

```bash
# Check worker counts
./get-worker-count.sh

# Monitor resources
docker stats

# View logs
docker-compose logs -f validator-worker
```

## 📚 Additional Resources

- [Benchmark README](README.md)
- [Docker Deployment Guide](../../README.md)
- [Kubernetes Deployment](../../../deployments/kubernetes/README.md)
- [Troubleshooting Guide](../../troubleshooting/)

## 🤝 Contributing

To add new worker configurations:

1. Edit `avalanche-comparison-benchmark.go`
2. Add new worker configurations to `workerVariations` array
3. Update documentation
4. Test with various scenarios
5. Submit PR with results

## 📝 Example Results

### Sample Performance Data

```
Configuration (V,C,D) | Total | TPS   | Latency | CPU % | Speedup
(1,1,1)              | 3     | 4,200 | 238ms   | 45%   | 1.1x
(3,2,2)              | 7     | 9,800 | 102ms   | 68%   | 2.5x  
(6,4,3)              | 13    | 18,500| 54ms    | 79%   | 4.7x
```

### Optimal Configurations

**Best Overall Performance**: (6,4,3) - 18,500 TPS
**Most Efficient**: (3,2,2) - 1,400 TPS/worker
**Resource Balanced**: (3,2,2) - 68% CPU usage

---

**Happy Testing! 🚀** 