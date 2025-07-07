# Avalanche Microservices vs Monolith Benchmark

Sistem benchmark komprehensif untuk membandingkan performa Avalanche blockchain menggunakan arsitektur microservices paralel vs monolith tradisional.

## 🎯 Tujuan Benchmark

Benchmark ini bertujuan untuk:
- Membandingkan throughput (TPS) antara arsitektur microservices dan monolith
- Menganalisis latency dan response time pada berbagai beban kerja
- Mengukur penggunaan resource (CPU, Memory, Network)
- Mengevaluasi skalabilitas pada berbagai volume transaksi
- Memberikan rekomendasi arsitektur berdasarkan hasil pengujian

## 📊 Test Cases

Benchmark mencakup 4 skenario pengujian dengan worker nodes paralel:

1. **Small Load**: 
   - 1,000 transaksi dengan 10 concurrent users
   - 3 consensus workers, 3 validator workers, 3 DAG state workers

2. **Medium Load**: 
   - 5,000 transaksi dengan 25 concurrent users
   - 4-5 consensus workers, 4-5 validator workers, 4-5 DAG state workers

3. **Large Load**: 
   - 10,000 transaksi dengan 50 concurrent users
   - 5-7 consensus workers, 5-7 validator workers, 5-7 DAG state workers

4. **High Load**: 
   - 20,000 transaksi dengan 100 concurrent users
   - 8-10 consensus workers, 8-10 validator workers, 8-10 DAG state workers

## 🛠️ Arsitektur Paralel

### Worker Node Configuration

```yaml
# Base Configuration per Worker Type
replicas: 5  # Base replicas
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"

# Auto-scaling
minReplicas: 3
maxReplicas: 15
metrics:
  - cpu: 70%
  - memory: 80%

# Worker Pool
env:
  - WORKER_POOL_SIZE: "5"
  - BATCH_SIZE: "100"
  - METRICS_ENABLED: "true"
  - METRICS_INTERVAL: "15s"
```

### Pod Distribution

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - [worker-type]
          topologyKey: "kubernetes.io/hostname"
```

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)
```bash
# Clone repository
git clone <repository-url>
cd avalanche-parallel/microservices/scripts/benchmark

# Run automated setup and benchmark
chmod +x setup-and-run.sh
./setup-and-run.sh
```

### Option 2: Manual Setup

#### 1. Install Dependencies
```bash
# Install Python dependencies
pip3 install -r requirements.txt

# Setup Go dependencies
go mod tidy
```

#### 2. Setup Local Registry & Deploy Workers
```bash
# Start local registry
docker run -d -p 5000:5000 --restart=always --name registry registry:2

# Deploy worker nodes
./run-avalanche-benchmark.sh --build --registry localhost:5000
```

#### 3. Verify Worker Deployment
```bash
# Check worker nodes
kubectl get pods -n avalanche-parallel -l type=worker

# Verify worker health
./test-setup.sh
```

## 📁 File Structure

```
scripts/benchmark/
├── README.md                           # Dokumentasi ini
├── setup-and-run.sh                    # Setup otomatis dan run benchmark
├── run-avalanche-benchmark.sh          # Script utama Linux/macOS
├── run-avalanche-benchmark.ps1         # Script utama Windows
├── avalanche-comparison-benchmark.go   # Core benchmark logic dengan worker support
├── generate-benchmark-graphs.py        # Graph generator
├── go.mod                              # Go dependencies
├── requirements.txt                    # Python dependencies
└── results/                            # Output directory
    ├── benchmark-results/              # JSON dan CSV data
    └── benchmark-graphs/               # PNG graphs
```

## 🔧 Configuration Options

### Benchmark Parameters

Script mendukung berbagai opsi konfigurasi:

```bash
# Skip tertentu steps
./run-avalanche-benchmark.sh --skip-setup
./run-avalanche-benchmark.sh --skip-microservices
./run-avalanche-benchmark.sh --skip-monolith

# Custom registry
./run-avalanche-benchmark.sh --registry your-registry.com:5000

# Skip graph generation
./run-avalanche-benchmark.sh --no-graphs

# Skip cleanup
./run-avalanche-benchmark.sh --no-cleanup
```

### Environment Variables

```bash
export BENCHMARK_RESULTS_DIR="/custom/results/path"
export BENCHMARK_GRAPHS_DIR="/custom/graphs/path"
export MICROSERVICES_ENDPOINT="http://localhost:30080"
export MONOLITH_ENDPOINT="http://localhost:9650"
```

## 📈 Output dan Results

### Generated Files

#### 1. Raw Data
- `benchmark_results_YYYYMMDD_HHMMSS.json` - Raw benchmark data
- `throughput_comparison_YYYYMMDD_HHMMSS.csv` - Throughput metrics
- `latency_comparison_YYYYMMDD_HHMMSS.csv` - Latency metrics
- `resource_usage_YYYYMMDD_HHMMSS.csv` - Resource utilization
- `worker_metrics.csv` - Worker node performance data
- `queue_metrics.csv` - Queue length monitoring data

#### 2. Reports
- `final_report_YYYYMMDD_HHMMSS.md` - Comprehensive analysis report
- `benchmark_report_YYYYMMDD_HHMMSS.md` - Detailed technical report

#### 3. Visualizations
- `throughput_comparison.png` - TPS comparison chart
- `latency_comparison.png` - Latency analysis
- `resource_usage_comparison.png` - CPU/Memory usage
- `scalability_analysis.png` - Scalability characteristics
- `speedup_analysis.png` - Performance improvement factors
- `performance_summary_dashboard.png` - Comprehensive dashboard
- `worker_performance.png` - Worker node performance graphs
- `queue_analysis.png` - Task queue analysis

### Sample Output

```
📊 BENCHMARK SUMMARY (WITH WORKER NODES)
==================================================
Test Case                    | Architecture  | Workers | TPS    | Avg Latency (ms) | CPU % | Memory (MB)
Small_Load_1K_Transactions  | microservices| 3x3     | 245.67 | 12.3             | 45.2  | 892.1
Small_Load_1K_Transactions  | monolith     | N/A     | 189.34 | 18.7             | 67.8  | 634.5
Medium_Load_5K_Transactions | microservices| 5x3     | 412.89 | 15.6             | 52.1  | 1024.3
Medium_Load_5K_Transactions | monolith     | N/A     | 298.45 | 24.2             | 78.9  | 745.2
Large_Load_10K_Transactions | microservices| 7x3     | 789.45 | 18.2             | 64.3  | 1256.7
Large_Load_10K_Transactions | monolith     | N/A     | 456.78 | 35.6             | 89.2  | 892.4
High_Load_20K_Transactions  | microservices| 10x3    | 1245.67| 22.4             | 72.5  | 1512.3
High_Load_20K_Transactions  | monolith     | N/A     | 678.90 | 48.9             | 94.7  | 1024.8
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Worker Node Issues
```bash
# Check worker status
kubectl get pods -n avalanche-parallel -l type=worker

# Check worker logs
kubectl logs -l type=worker -n avalanche-parallel

# Restart workers
kubectl rollout restart deployment -n avalanche-parallel -l type=worker
```

#### 2. Redis Queue Issues
```bash
# Check queue lengths
kubectl exec -n avalanche-parallel svc/redis -- redis-cli llen consensus_tasks
kubectl exec -n avalanche-parallel svc/redis -- redis-cli llen validation_tasks
kubectl exec -n avalanche-parallel svc/redis -- redis-cli llen dag_state_tasks

# Clear queues if needed
kubectl exec -n avalanche-parallel svc/redis -- redis-cli flushall
```

#### 3. Resource Issues
```bash
# Check resource usage
kubectl top pods -n avalanche-parallel

# Scale workers
kubectl scale deployment consensus-worker -n avalanche-parallel --replicas=5
kubectl scale deployment validator-worker -n avalanche-parallel --replicas=5
kubectl scale deployment dag-state-worker -n avalanche-parallel --replicas=5
```

### Performance Optimization

#### Worker Node Tuning
- Adjust `WORKER_POOL_SIZE` based on CPU cores
- Tune `BATCH_SIZE` for optimal throughput
- Configure proper resource limits
- Enable metrics for monitoring

#### Queue Management
- Monitor queue lengths
- Adjust worker counts based on queue depth
- Set appropriate timeout values
- Configure retry policies

## 📊 Interpreting Results

### Key Metrics

#### 1. Throughput (TPS)
- **Higher is better**
- Measures transactions processed per second
- Should scale with worker count

#### 2. Latency (ms)
- **Lower is better**
- Measures response time
- Should remain stable with more workers

#### 3. Worker Utilization
- **Balanced is better**
- CPU usage per worker
- Memory usage per worker
- Queue distribution

#### 4. Scaling Efficiency
- **Higher is better**
- Throughput increase per worker
- Resource usage efficiency
- Queue processing rate

### Recommendations

#### Choose Microservices When:
- High transaction volume (>5K TPS)
- Need horizontal scalability
- Complex processing requirements
- Team expertise in distributed systems
- Can manage multiple worker nodes

#### Choose Monolith When:
- Simple use cases (<1K TPS)
- Limited operational complexity
- Small development team
- Quick deployment needed
- Resource constraints

## 🔬 Advanced Usage

### Custom Worker Configuration

Edit worker deployment YAML:
```yaml
spec:
  replicas: 7  # Increase base replicas
  template:
    spec:
      containers:
        - name: worker
          env:
            - name: WORKER_POOL_SIZE
              value: "8"
            - name: BATCH_SIZE
              value: "200"
```

### Custom Test Cases

Edit `avalanche-comparison-benchmark.go`:
```go
testCases: []TestCase{
    {
        Name:             "Custom_High_Load",
        TransactionCount: 15000,
        ConcurrentUsers:  75,
        TransactionSize:  1536,
        WorkerCount:     10,
        BatchSize:       150,
    },
}
```

### Integration with CI/CD

```yaml
# GitHub Actions example
name: Avalanche Benchmark

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Kubernetes
      uses: helm/kind-action@v1.5.0
    
    - name: Deploy Workers
      run: |
        cd microservices/scripts/benchmark
        ./setup-and-run.sh --registry localhost:5000
    
    - name: Run Benchmark
      run: ./run-avalanche-benchmark.sh
    
    - name: Upload Results
      uses: actions/upload-artifact@v3
      with:
        name: benchmark-results
        path: microservices/benchmark-results/
```

## 🤝 Contributing

1. Fork repository
2. Create feature branch
3. Add/modify benchmark scenarios
4. Test thoroughly
5. Submit pull request

## 📝 License

[Add license information]

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