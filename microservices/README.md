# Avalanche Microservices Worker Pool Architecture

Implementasi arsitektur microservices untuk Avalanche blockchain dengan **parallel worker pools** dan kemampuan horizontal scaling yang dapat di-deploy melalui Docker dan Kubernetes.

## 🏗️ Arsitektur Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   API Gateway   │───▶│  Load Balancer  │───▶│   Task Queue    │
│   (1 instance)  │    │   (HAProxy)     │    │    (Redis)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                        ┌─────────────┼─────────────┐
                                        │             │             │
                                        ▼             ▼             ▼
                               ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
                               │   Worker    │ │   Worker    │ │   Worker    │
                               │   Pool 1    │ │   Pool 2    │ │   Pool 3    │
                               │             │ │             │ │             │
                               ├─────────────┤ ├─────────────┤ ├─────────────┤
                               │ Consensus   │ │ Validator   │ │ DAG + State │
                               │ Workers     │ │ Workers     │ │ Workers     │
                               │ (2-10 pods) │ │ (3-15 pods) │ │ (2-8 pods)  │
                               └─────────────┘ └─────────────┘ └─────────────┘
                                       │             │             │
                                       └─────────────┼─────────────┘
                                                     │
                                                     ▼
                                            ┌─────────────────┐
                                            │   Result Store  │
                                            │  (PostgreSQL)   │
                                            └─────────────────┘
```

## 🔧 Worker Pool Types

### 1. Consensus Worker Pool
- **Purpose**: Memproses vertex consensus dan polling secara parallel
- **Location**: `microservices/workers/consensus-worker/`
- **Scaling**: 2-10 pods berdasarkan load vertex
- **Port**: 8080 (metrics)
- **Tasks**: 
  - Vertex validation
  - Consensus polling
  - Confidence calculation
  - Finalization decisions

### 2. Validator Worker Pool  
- **Purpose**: Validasi transaksi dan signature verification parallel
- **Location**: `microservices/workers/validator-worker/`
- **Scaling**: 3-15 pods berdasarkan transaction volume
- **Port**: 8081 (metrics)
- **Tasks**:
  - Transaction validation
  - Signature verification
  - Balance checking
  - Transaction formatting

### 3. DAG + State Worker Pool
- **Purpose**: DAG management dan state updates
- **Scaling**: 2-8 pods berdasarkan state operations
- **Port**: 8082 (metrics)
- **Tasks**:
  - Vertex ancestry tracking
  - State transitions
  - Database updates
  - Query processing

## 🚀 Quick Start

### Prerequisites
- Go 1.21+
- Docker & Docker Compose
- Kubernetes (kubectl) - untuk production
- Redis (akan di-setup otomatis)
- PostgreSQL (akan di-setup otomatis)

### 1. Development dengan Docker Compose

```bash
# Clone dan masuk ke direktori
cd microservices

# Build semua worker images
./scripts/deployment/build-microservices.sh --optimize

# Start worker pools (development)
docker-compose -f docker-compose.worker-pools.yml up -d

# Check status
docker-compose -f docker-compose.worker-pools.yml ps

# View logs
docker-compose -f docker-compose.worker-pools.yml logs -f consensus-worker-1
```

### 2. Production dengan Kubernetes

```bash
# Deploy ke Kubernetes
./scripts/deployment/deploy-worker-pools.sh deploy

# Check deployment status
./scripts/deployment/deploy-worker-pools.sh status

# Scale specific worker pool
./scripts/deployment/deploy-worker-pools.sh scale consensus-worker 5

# Clean up
./scripts/deployment/deploy-worker-pools.sh clean
```

### 3. Generate Microservices (First Time)

```bash
# Generate all microservices structure
./microservices/generator/generate-all.sh

# Atau manual jika ada issue dengan permissions
cd microservices/generator
bash generate-all.sh
```

## 📊 Benchmarking & Testing

### Worker Pool Benchmark

```bash
# Run full benchmark dengan berbagai konfigurasi worker
./scripts/benchmark/worker-pool-benchmark.sh benchmark

# Quick test
./scripts/benchmark/worker-pool-benchmark.sh test

# Check worker status
./scripts/benchmark/worker-pool-benchmark.sh status
```

### Microservices vs Monolith Comparison

```bash
# Compare performance: microservices vs monolith
./scripts/benchmark/run-microservices-benchmark.sh

# Dengan custom parameters
./scripts/benchmark/run-microservices-benchmark.sh --transactions 5000 --threads 8 --duration 120
```

## 🎛️ Configuration

### Environment Variables

#### Consensus Workers
```bash
WORKER_ID=consensus-worker-1
REDIS_URL=redis://redis:6379
TASK_QUEUE=consensus_tasks
RESULT_QUEUE=consensus_results
MAX_WORKERS=10
LOG_LEVEL=info
```

#### Validator Workers
```bash
WORKER_ID=validator-worker-1
REDIS_URL=redis://redis:6379
TASK_QUEUE=validation_tasks
RESULT_QUEUE=validation_results
MAX_WORKERS=15
LOG_LEVEL=info
```

#### DAG+State Workers
```bash
WORKER_ID=dag-state-worker-1
REDIS_URL=redis://redis:6379
DB_URL=postgres://avalanche:avalanche123@postgres:5432/avalanche
TASK_QUEUE=dag_state_tasks
RESULT_QUEUE=dag_state_results
MAX_WORKERS=8
LOG_LEVEL=info
```

### Auto-Scaling Configuration (Kubernetes)

```yaml
# Consensus Workers HPA
minReplicas: 2
maxReplicas: 10
metrics:
  - CPU > 70% → scale up
  - Queue depth > 100 → scale up

# Validator Workers HPA  
minReplicas: 3
maxReplicas: 15
metrics:
  - CPU > 80% → scale up
  - Queue depth > 200 → scale up

# DAG+State Workers HPA
minReplicas: 2
maxReplicas: 8
metrics:
  - CPU > 75% → scale up
  - Memory > 80% → scale up
```

## 🔍 Monitoring & Debugging

### Health Checks

```bash
# API Gateway
curl http://localhost:9650/health

# Consensus Workers
curl http://localhost:8080/health

# Validator Workers  
curl http://localhost:8081/health

# DAG+State Workers
curl http://localhost:8082/health
```

### Metrics Endpoints

```bash
# Prometheus metrics
curl http://localhost:8080/metrics  # Consensus
curl http://localhost:8081/metrics  # Validator
curl http://localhost:8082/metrics  # DAG+State

# Prometheus dashboard
open http://localhost:9090

# Grafana dashboard  
open http://localhost:3000
# Login: admin/admin
```

### Queue Monitoring

```bash
# Check queue depths
docker exec avalanche-redis redis-cli LLEN consensus_tasks
docker exec avalanche-redis redis-cli LLEN validation_tasks
docker exec avalanche-redis redis-cli LLEN dag_state_tasks

# Check processed results
docker exec avalanche-redis redis-cli LLEN consensus_results
docker exec avalanche-redis redis-cli LLEN validation_results
docker exec avalanche-redis redis-cli LLEN dag_state_results
```

### Logs

```bash
# Docker Compose logs
docker-compose -f docker-compose.worker-pools.yml logs -f [service-name]

# Kubernetes logs
kubectl logs -f deployment/consensus-worker-pool -n avalanche
kubectl logs -f deployment/validator-worker-pool -n avalanche
kubectl logs -f deployment/dag-state-worker-pool -n avalanche
```

## 🛠️ Development

### Directory Structure

```
microservices/
├── README.md                          # This file
├── architecture/
│   └── worker-pool-design.md         # Architecture documentation
├── generator/
│   └── generate-all.sh               # Generate microservices structure
├── services/                         # Legacy microservices (single instance)
│   ├── api-gateway/
│   ├── consensus/
│   ├── validator/
│   ├── dag/
│   └── state/
├── workers/                          # NEW: Worker pool implementations
│   ├── consensus-worker/
│   │   ├── cmd/main.go              # Consensus worker implementation
│   │   └── Dockerfile
│   ├── validator-worker/
│   │   ├── cmd/main.go              # Validator worker implementation
│   │   └── Dockerfile
│   └── dag-state-worker/
│       ├── cmd/main.go              # DAG+State worker implementation
│       └── Dockerfile
├── shared/
│   ├── common/                       # Shared types and interfaces
│   └── middleware/                   # Shared middleware
├── k8s/
│   ├── worker-pools/                 # Kubernetes manifests
│   │   ├── consensus-worker-deployment.yaml
│   │   ├── validator-worker-deployment.yaml
│   │   └── dag-state-worker-deployment.yaml
│   └── ...
├── docker-compose.yml               # Legacy single service
├── docker-compose.worker-pools.yml  # NEW: Worker pools deployment
└── go.mod
```

### Adding New Worker Types

1. **Create worker directory**:
   ```bash
   mkdir -p microservices/workers/new-worker/cmd
   ```

2. **Implement worker** (see existing workers as template):
   ```go
   // microservices/workers/new-worker/cmd/main.go
   // Implement NewWorker struct with Start(), Stop(), ProcessTask()
   ```

3. **Create Dockerfile**:
   ```dockerfile
   # microservices/workers/new-worker/Dockerfile
   FROM golang:1.21-alpine AS builder
   # ... build steps
   ```

4. **Add to deployments**:
   - Update `docker-compose.worker-pools.yml`
   - Create Kubernetes deployment YAML
   - Add to deployment scripts

### Testing Individual Workers

```bash
# Test specific worker
docker run --rm -d --name test-consensus \
  -e WORKER_ID=test-consensus \
  -e REDIS_URL=redis://localhost:6379 \
  avalanche-consensus-worker:latest

# Send test task
echo '{"id":"test","type":"vertex_validation","vertex_id":"123"}' | \
  redis-cli -x LPUSH consensus_tasks

# Check result
redis-cli BRPOP consensus_results 5
```

## 📈 Performance Tuning

### Worker Pool Sizing

#### Low Load (< 1,000 TPS)
```yaml
consensus: 2 workers
validator: 3 workers  
dag-state: 2 workers
Total: 7 workers
```

#### Medium Load (1,000-5,000 TPS)
```yaml
consensus: 4 workers
validator: 6 workers
dag-state: 3 workers  
Total: 13 workers
```

#### High Load (> 5,000 TPS)
```yaml
consensus: 8-10 workers
validator: 12-15 workers
dag-state: 6-8 workers
Total: 26-33 workers
```

### Resource Optimization

```yaml
# Resource requests/limits per worker type
consensus_workers:
  requests: { cpu: "500m", memory: "512Mi" }
  limits: { cpu: "1000m", memory: "1Gi" }
  
validator_workers:
  requests: { cpu: "250m", memory: "256Mi" }
  limits: { cpu: "500m", memory: "512Mi" }
  
dag_state_workers:
  requests: { cpu: "750m", memory: "1Gi" }
  limits: { cpu: "1500m", memory: "2Gi" }
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Workers tidak start
```bash
# Check logs
docker-compose -f docker-compose.worker-pools.yml logs consensus-worker-1

# Check Redis connection
docker exec avalanche-redis redis-cli ping

# Check environment variables
docker exec consensus-worker-1 env | grep REDIS_URL
```

#### 2. Tasks tidak diproses
```bash
# Check queue depths
docker exec avalanche-redis redis-cli LLEN consensus_tasks

# Check worker status
curl http://localhost:8080/health

# Check worker metrics
curl http://localhost:8080/metrics | grep processed
```

#### 3. Auto-scaling tidak bekerja
```bash
# Check HPA status (Kubernetes)
kubectl get hpa -n avalanche

# Check metrics server
kubectl top pods -n avalanche

# Check custom metrics
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/avalanche/redis_queue_depth"
```

#### 4. Performance issues
```bash
# Check resource usage
docker stats

# Check queue bottlenecks  
./scripts/benchmark/worker-pool-benchmark.sh status

# Tune worker count
./scripts/deployment/deploy-worker-pools.sh scale validator-worker 10
```

## 🎯 Best Practices

### 1. Production Deployment
- Gunakan Kubernetes untuk production
- Setup monitoring dengan Prometheus + Grafana
- Configure auto-scaling berdasarkan queue depth
- Use persistent storage untuk Redis dan PostgreSQL

### 2. Development
- Gunakan Docker Compose untuk development
- Enable debug logging: `LOG_LEVEL=debug`
- Use volume mounts untuk rapid development

### 3. Scaling Strategy
- Monitor queue depths sebagai primary metric
- Scale validator workers paling aggressive (highest volume)
- Scale consensus workers based on vertex complexity
- Scale DAG+State workers conservatively (resource intensive)

### 4. Monitoring
- Setup alerts untuk queue depth > threshold
- Monitor worker health dan restart otomatis
- Track throughput dan latency metrics
- Setup log aggregation untuk debugging

## 🔗 API Reference

### Health Endpoints
- `GET /health` - Service health status
- `GET /ready` - Readiness probe
- `GET /metrics` - Prometheus metrics

### Task Queue APIs
- **Consensus Tasks**: `consensus_tasks` queue
- **Validation Tasks**: `validation_tasks` queue  
- **DAG/State Tasks**: `dag_state_tasks` queue

### Scaling APIs (Kubernetes)
```bash
# Manual scaling
kubectl scale deployment consensus-worker-pool --replicas=5 -n avalanche

# HPA configuration
kubectl get hpa consensus-worker-hpa -n avalanche -o yaml
```

---

## 📋 Summary

Implementasi ini memberikan:

✅ **True Parallel Processing**: Multiple workers memproses tasks secara bersamaan  
✅ **Horizontal Scaling**: Auto-scaling berdasarkan load dan queue depth  
✅ **Fault Tolerance**: Worker failure tidak mempengaruhi sistem keseluruhan  
✅ **Load Distribution**: Redis queues mendistribusi tasks secara merata  
✅ **Production Ready**: Kubernetes deployment dengan monitoring lengkap  
✅ **Development Friendly**: Docker Compose untuk local development  

**Expected Performance**: 2-5x improvement dengan parallel worker processing dibanding single-threaded approach.

Untuk pertanyaan atau issues, silakan check troubleshooting section atau buat issue di repository. 