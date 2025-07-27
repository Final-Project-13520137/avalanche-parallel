# Avalanche Parallel Kubernetes Deployment

Deployment Kubernetes untuk sistem Avalanche Parallel dengan microservices architecture yang mendukung auto-scaling worker nodes.

## 🏗️ Arsitektur

### Actual Kubernetes Architecture

```
                     KUBERNETES DEPLOYMENT
                                                                   
┌────────────────────────────────────────────────────────────────┐
│                     KUBERNETES CLUSTER                         │
│                                                               │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐         │
│  │ Ingress     │   │ Service     │   │ ConfigMap   │         │
│  │ Controller  │   │ Mesh        │   │ & Secrets   │         │
│  └──────┬──────┘   └─────────────┘   └─────────────┘         │
│         │                                                     │
│         ▼                                                     │
│  ┌─────────────┐                                             │
│  │ API Gateway │                                             │
│  │ Service     │                                             │
│  └──────┬──────┘                                             │
│         │                                                     │
│         ▼                                                     │
│  ┌─────────────┐                                             │
│  │Redis Queue  │ Queue Channels:                             │
│  │StatefulSet  │ • validation_tasks                          │
│  └──────┬──────┘ • consensus_tasks                           │
│         │        • dag_state_tasks                           │
│         │        • results_queue                             │
│         ▼                                                     │
│  ┌──────────────────────────────────────────────────┐        │
│  │              WORKER DEPLOYMENTS                  │        │
│  │                                                  │        │
│  │ ┌────────────┐  ┌────────────┐  ┌────────────┐  │        │
│  │ │ Validator  │  │ Consensus  │  │ DAG+State  │  │        │
│  │ │ HPA        │  │ HPA        │  │ HPA        │  │        │
│  │ │            │  │            │  │            │  │        │
│  │ │Scale:      │  │Scale:      │  │Scale:      │  │        │
│  │ │3-15 pods   │  │2-10 pods   │  │2-8 pods    │  │        │
│  │ │            │  │            │  │            │  │        │
│  │ │Resources:  │  │Resources:  │  │Resources:  │  │        │
│  │ │• CPU: 500m │  │• CPU: 1000m│  │• CPU: 200m │  │        │
│  │ │• Mem: 1Gi  │  │• Mem: 2Gi  │  │• Mem: 4Gi  │  │        │
│  │ └────────────┘  └────────────┘  └────────────┘  │        │
│  │                                                  │        │
│  │ Scaling Metrics:                                 │        │
│  │ • CPU Usage > 70%                               │        │
│  │ • Memory Usage > 80%                            │        │
│  │ • Queue Length > 30 msgs/pod                    │        │
│  └──────────────────────────────────────────────────┘        │
│                          │                                   │
│                          ▼                                   │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐        │
│  │ PostgreSQL  │   │ Prometheus  │   │ Grafana     │        │
│  │ StatefulSet │   │ Deployment  │   │ Deployment  │        │
│  └─────────────┘   └─────────────┘   └─────────────┘        │
└────────────────────────────────────────────────────────────────┘

Worker Pod Details:
1. Validator Workers:
   • Goroutine Pool: 50 per pod
   • Memory Request: 512Mi
   • Memory Limit: 1Gi
   • CPU Request: 250m
   • CPU Limit: 500m
   • Max Batch Size: 100 tx
   • Health Check: /health
   • Readiness Probe: 5s
   • Liveness Probe: 10s

2. Consensus Workers:
   • Goroutine Pool: 30 per pod
   • Memory Request: 1Gi
   • Memory Limit: 2Gi
   • CPU Request: 500m
   • CPU Limit: 1000m
   • Max Batch Size: 50 tx
   • Health Check: /health
   • Readiness Probe: 5s
   • Liveness Probe: 10s

3. DAG+State Workers:
   • Goroutine Pool: 20 per pod
   • Memory Request: 2Gi
   • Memory Limit: 4Gi
   • CPU Request: 100m
   • CPU Limit: 200m
   • Max Batch Size: 25 tx
   • Health Check: /health
   • Readiness Probe: 5s
   • Liveness Probe: 10s

Auto-Scaling Configuration:
• Scale Up:
  - CPU > 70% for 3 minutes
  - Memory > 80% for 3 minutes
  - Queue Length > 30 messages/pod
  - Max Scale Up Rate: 2 pods per minute

• Scale Down:
  - CPU < 50% for 10 minutes
  - Memory < 60% for 10 minutes
  - Queue Empty for 5 minutes
  - Max Scale Down Rate: 1 pod per 5 minutes

• Stabilization:
  - Scale Up Window: 0s (immediate)
  - Scale Down Window: 300s (5 minutes)
  - Pod Disruption Budget: minAvailable: 1
```

## 📋 Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl CLI
- Docker (untuk build images)
- Helm (optional, untuk package management)

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/Final-Project-13520137/avalanche-parallel.git
cd avalanche-parallel-dag/deployments/kubernetes
```

### 2. Setup Kubernetes Cluster (if needed)

**Windows (PowerShell):**
```powershell
# Setup Docker Desktop Kubernetes
.\setup-k8s.ps1 -Provider docker-desktop

# Or setup kind cluster
.\setup-k8s.ps1 -Provider kind

# Or setup minikube
.\setup-k8s.ps1 -Provider minikube
```

**Linux/WSL/Ubuntu:**
```bash
# Make script executable
chmod +x setup-k8s.sh

# Setup Docker Desktop Kubernetes
./setup-k8s.sh --provider docker-desktop

# Or setup kind cluster
./setup-k8s.sh --provider kind

# Or setup minikube
./setup-k8s.sh --provider minikube
```

### 3. Deploy dengan Script

**Kubernetes Deployment:**

*Windows (PowerShell):*
```powershell
.\deploy.ps1 -Build -Registry localhost:5000
```

*Linux/WSL/Ubuntu:*
```bash
chmod +x deploy.sh
./deploy.sh --build --registry localhost:5000
```

**Docker Compose Alternative (Recommended for local testing):**

*Windows (PowerShell):*
```powershell
.\deploy-docker.ps1 -Build -Workers 3
```

*Linux/WSL/Ubuntu:*
```bash
chmod +x deploy-docker.sh
./deploy-docker.sh --build --workers 3
```

### 3. Deploy Manual
```bash
# Create namespace
kubectl create namespace avalanche-parallel

# Deploy all components
kubectl apply -k .

# Or apply individual files
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-message-queue.yaml
kubectl apply -f 02-main-node.yaml
kubectl apply -f 03-worker-deployment.yaml
kubectl apply -f 04-api-gateway.yaml
kubectl apply -f 05-monitoring.yaml
```

## 📊 Auto-Scaling Configuration

Worker nodes dikonfigurasi dengan Horizontal Pod Autoscaler (HPA) yang akan scale berdasarkan:

- **CPU Usage**: Scale up jika CPU > 70%
- **Memory Usage**: Scale up jika Memory > 80%
- **Queue Length**: Scale up jika message queue > 30 messages/pod

### Manual Scaling

Untuk melakukan manual scaling, gunakan script yang telah disediakan:

**Windows (PowerShell):**
```powershell
# Scale di environment Docker
.\scripts\scaling\scale-workers.ps1 -Workers 5 -Environment docker

# Scale di environment Kubernetes
.\scripts\scaling\scale-workers.ps1 -Workers 10 -Environment kubernetes
```

**Linux/WSL/Ubuntu:**
```bash
# Make script executable
chmod +x scripts/scaling/scale-workers.sh

# Scale di environment Docker
./scripts/scaling/scale-workers.sh --environment docker 5

# Scale di environment Kubernetes
./scripts/scaling/scale-workers.sh --environment kubernetes 10
```

Atau gunakan perintah Kubernetes/Docker langsung:

```bash
# Scale menggunakan kubectl
kubectl scale deployment avalanche-worker -n avalanche-parallel --replicas=10

# Scale menggunakan docker-compose
docker-compose -f docker-compose.worker-pools.yml up -d --scale worker=5

# Check status scaling
kubectl get pods -n avalanche-parallel -l app=avalanche-worker  # Untuk Kubernetes
docker-compose ps  # Untuk Docker
```

## 🔍 Monitoring

### Accessing Services

Setelah deployment selesai, akses services melalui:

- **API Gateway**: `http://<NODE_IP>:30080`
- **Grafana Dashboard**: `http://<NODE_IP>:30300` (admin/avalanche123)
- **RabbitMQ Management**: Port forward ke `15672`

### Port Forwarding (Development)
```bash
# API Gateway
kubectl port-forward -n avalanche-parallel svc/avalanche-api-gateway 8080:80

# Grafana
kubectl port-forward -n avalanche-parallel svc/grafana 3000:3000

# RabbitMQ Management
kubectl port-forward -n avalanche-parallel svc/rabbitmq 15672:15672
```

## 🛠️ Configuration

### Environment Variables

**Main Node:**
- `ENABLE_DAG_STATE_MGMT`: Enable DAG state management
- `ENABLE_CONSENSUS_ORCH`: Enable consensus orchestration
- `ENABLE_RESULT_AGGREG`: Enable result aggregation
- `DAG_STATE_SYNC_INTERVAL`: Interval for DAG state synchronization
- `CONSENSUS_TIMEOUT`: Timeout for consensus operations

**Worker Node:**
- `ENABLE_TX_VALIDATION`: Enable transaction validation
- `ENABLE_SIGNATURE_VER`: Enable signature verification
- `ENABLE_CONSENSUS_VOTE`: Enable consensus voting
- `ENABLE_CONFIDENCE_CAL`: Enable confidence calculation
- `ENABLE_STATE_UPDATE`: Enable state updates
- `ENABLE_CONFLICT_DET`: Enable conflict detection
- `WORKER_CONCURRENCY`: Number of concurrent tasks per worker

### ConfigMap Customization
```bash
# Edit configuration
kubectl edit configmap avalanche-config -n avalanche-parallel

# Restart pods to apply changes
kubectl rollout restart deployment -n avalanche-parallel
```

## 📈 Performance Tuning

### Worker Performance
```yaml
# Adjust worker resources in 03-worker-deployment.yaml
resources:
  requests:
    memory: "1Gi"    # Minimum memory
    cpu: "500m"      # Minimum CPU
  limits:
    memory: "2Gi"    # Maximum memory
    cpu: "1000m"     # Maximum CPU
```

### HPA Tuning
```yaml
# Adjust scaling behavior
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300  # Wait 5 min before scale down
  scaleUp:
    stabilizationWindowSeconds: 0    # Scale up immediately
    policies:
    - type: Percent
      value: 100                     # Double pods each time
      periodSeconds: 15
```

## 🔧 Troubleshooting

### Check Pod Status
```bash
# All pods
kubectl get pods -n avalanche-parallel

# Detailed pod info
kubectl describe pod <POD_NAME> -n avalanche-parallel

# Pod logs
kubectl logs -n avalanche-parallel <POD_NAME> -f
```

### Common Issues

1. **Workers not scaling:**
   ```bash
   # Check HPA status
   kubectl describe hpa avalanche-worker-hpa -n avalanche-parallel
   
   # Check metrics server
   kubectl get deployment metrics-server -n kube-system
   ```

2. **Message Queue Connection:**
   ```bash
   # Check RabbitMQ
   kubectl exec -n avalanche-parallel rabbitmq-0 -- rabbitmqctl status
   ```

3. **Storage Issues:**
   ```bash
   # Check PVC status
   kubectl get pvc -n avalanche-parallel
   ```

## 🔄 Updates and Maintenance

### Rolling Update
```bash
# Update image
kubectl set image deployment/avalanche-worker -n avalanche-parallel \
  worker=your-registry/avalanche-worker:v2.0.0

# Check rollout status
kubectl rollout status deployment/avalanche-worker -n avalanche-parallel
```

### Backup
```bash
# Backup configurations
kubectl get all,pvc,configmap,secret -n avalanche-parallel -o yaml > backup.yaml
```

## 🗑️ Cleanup

```bash
# Delete all resources
kubectl delete namespace avalanche-parallel

# Or delete specific deployment
kubectl delete -k .
```

## 📚 Additional Resources

- [Avalanche Documentation](https://docs.avax.network/)
- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [RabbitMQ Kubernetes Operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html) 