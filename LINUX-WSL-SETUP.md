# Avalanche Parallel - Linux/WSL/Ubuntu Setup Guide

Panduan lengkap untuk menjalankan Avalanche Parallel di Linux, WSL, atau Ubuntu.

## 🚀 Quick Start

### 1. Clone dan Setup Permissions
```bash
# Clone repository
git clone https://github.com/Final-Project-13520137/avalanche-parallel-dag.git
cd avalanche-parallel-dag

# Set permissions untuk semua script
chmod +x make-executable.sh && ./make-executable.sh
```

### 2. Fix Go Compatibility Issues
```bash
# Fix Go version dan compatibility issues
./fixer/fix-go-version.sh
./fixer/fix-go-compatibility.sh
```

## 🐳 Docker Compose Deployment (Recommended for Development)

### Prerequisites
- Docker Engine atau Docker Desktop
- Docker Compose

### Install Docker (jika belum ada)
```bash
# Install Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose (jika belum ada)
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Restart atau logout/login untuk apply group changes
```

### Deploy dengan Script
```bash
# Deploy dengan 3 worker nodes
./deploy-docker.sh --build --workers 3

# Atau deploy dengan 5 worker nodes
./deploy-docker.sh --build --workers 5

# Check status
./deploy-docker.sh --status

# View logs
./deploy-docker.sh --logs

# Stop services
./deploy-docker.sh --stop
```

### Deploy Manual dengan Docker Compose
```bash
# Start services
docker-compose -f config/docker-compose.yml up -d --scale worker=3

# View logs
docker-compose -f config/docker-compose.yml logs -f

# Stop services
docker-compose -f config/docker-compose.yml down
```

## ☸️ Kubernetes Deployment (Production)

### Prerequisites
- kubectl
- Docker
- Kubernetes cluster (Docker Desktop, kind, atau minikube)

### Setup Kubernetes Cluster
```bash
# Option 1: Docker Desktop (jika menggunakan Docker Desktop)
./setup-k8s.sh --provider docker-desktop

# Option 2: kind (Kubernetes in Docker)
./setup-k8s.sh --provider kind

# Option 3: minikube
./setup-k8s.sh --provider minikube

# With custom cluster name
./setup-k8s.sh --provider kind --name my-cluster
```

### Deploy to Kubernetes
```bash
cd deployments/kubernetes
./deploy.sh --build --registry localhost:5000
```

### Manual Kubernetes Deployment
```bash
cd deployments/kubernetes

# Create namespace
kubectl create namespace avalanche-parallel

# Deploy all components
kubectl apply -k .

# Or deploy individual files
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-message-queue.yaml
kubectl apply -f 02-main-node.yaml
kubectl apply -f 03-worker-deployment.yaml
kubectl apply -f 04-api-gateway.yaml
kubectl apply -f 05-monitoring.yaml
kubectl apply -f 06-grafana-dashboard.yaml
```

## 🔧 WSL-Specific Configuration

### Docker Desktop with WSL2
1. Install Docker Desktop on Windows
2. Enable WSL2 integration in Docker Desktop settings
3. Enable your WSL distribution in Docker Desktop > Settings > Resources > WSL Integration

### Docker Engine in WSL2
```bash
# Install Docker Engine directly in WSL2
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Start Docker daemon (add to ~/.bashrc for auto-start)
sudo service docker start
```

## 📊 Accessing Services

### Docker Compose Deployment
- **Avalanche Node API**: http://localhost:9650
- **Worker Health Check**: http://localhost:9652/health
- **Prometheus**: http://localhost:19090
- **Grafana**: http://localhost:13000 (admin/admin)
- **RabbitMQ Management**: http://localhost:15672 (guest/guest)

### Kubernetes Deployment
- **API Gateway**: http://localhost:30080
- **Grafana**: http://localhost:30300 (admin/avalanche123)
- **RabbitMQ Management**: Port forward to 15672

## 🛠️ Troubleshooting

### Permission Issues
```bash
# If you get permission denied errors
chmod +x make-executable.sh
./make-executable.sh

# Or set permissions manually
chmod +x setup-k8s.sh
chmod +x deploy-docker.sh
chmod +x deployments/kubernetes/deploy.sh
chmod +x fixer/*.sh
chmod +x scripts/*.sh
```

### Docker Issues in WSL
```bash
# Check Docker status
sudo service docker status

# Start Docker if not running
sudo service docker start

# Add user to docker group
sudo usermod -aG docker $USER

# Restart WSL or logout/login
```

### Go Build Issues
```bash
# Fix Go version issues
./fixer/fix-go-version.sh

# Fix all Go compatibility issues
./fixer/fix-all-go-issues.sh

# Fix specific issues
./fixer/fix-sorting.sh
./fixer/fix-imports.sh
```

### Kubernetes Issues
```bash
# Check cluster connectivity
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check pods
kubectl get pods -n avalanche-parallel

# Check logs
kubectl logs -n avalanche-parallel <pod-name>
```

### Metrics Server Issues
```bash
# If you get metrics server errors during deployment
./fix-metrics-server.sh

# Or manually check metrics server
kubectl get deployment metrics-server -n kube-system
kubectl logs -n kube-system deployment/metrics-server

# Test metrics server
kubectl top nodes
kubectl top pods -n avalanche-parallel
```

## 🚀 Performance Testing

### Run Benchmarks
```bash
# Run parallel benchmark
./scripts/run_parallel_benchmark.sh

# Run blockchain tests
./scripts/run_blockchain_tests.sh --benchmark

# Run transaction load test
go run ./scripts/transaction_load.go --benchmark
```

## 🔄 Management Commands

### Docker Compose
```bash
# Scale workers
docker-compose -f config/docker-compose.yml up -d --scale worker=5

# Restart services
./deploy-docker.sh --stop && ./deploy-docker.sh --build --workers 3

# View resource usage
docker stats
```

### Dynamic Node Scaling (Docker)
```bash
# Scale up workers dynamically with automatic port allocation
./docker-dynamic-scaler.sh scale-up --type worker --replicas 5

# Scale down workers
./docker-dynamic-scaler.sh scale-down --type worker --replicas 2

# Add single worker node
./docker-dynamic-scaler.sh add-node --type worker

# Add worker with specific port
./docker-dynamic-scaler.sh add-node --type worker --port 9662

# Remove specific node
./docker-dynamic-scaler.sh remove-node --type worker --port 9662

# List all nodes
./docker-dynamic-scaler.sh list

# Show status
./docker-dynamic-scaler.sh status

# Stop all dynamic nodes
./docker-dynamic-scaler.sh stop-all
```

### Kubernetes
```bash
# Scale workers
kubectl scale deployment avalanche-worker -n avalanche-parallel --replicas=10

# Check HPA status
kubectl get hpa -n avalanche-parallel

# Port forward for development
kubectl port-forward -n avalanche-parallel svc/avalanche-api-gateway 8080:80
kubectl port-forward -n avalanche-parallel svc/grafana 3000:3000
```

### Dynamic Node Scaling (Kubernetes)
```bash
# Scale up workers dynamically with automatic port allocation
./dynamic-node-scaler.sh scale-up --type worker --replicas 5

# Scale down workers
./dynamic-node-scaler.sh scale-down --type worker --replicas 2

# Add single worker node
./dynamic-node-scaler.sh add-node --type worker

# Add worker with specific port
./dynamic-node-scaler.sh add-node --type worker --port 9662

# Remove specific node
./dynamic-node-scaler.sh remove-node --type worker --port 9662

# Scale both main and worker nodes
./dynamic-node-scaler.sh scale-up --type both --replicas 3

# List all nodes
./dynamic-node-scaler.sh list

# Show status
./dynamic-node-scaler.sh status
```

## 📚 Additional Resources

- [Docker Installation Guide](https://docs.docker.com/engine/install/)
- [Kubernetes Installation Guide](https://kubernetes.io/docs/setup/)
- [WSL2 Docker Setup](https://docs.docker.com/desktop/windows/wsl/)
- [kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [minikube Getting Started](https://minikube.sigs.k8s.io/docs/start/)

## 🆘 Support

Jika mengalami masalah:
1. Periksa log dengan `./deploy-docker.sh --logs` atau `kubectl logs`
2. Pastikan semua prerequisites sudah terinstall
3. Jalankan `./make-executable.sh` untuk memastikan permissions
4. Periksa status Docker dengan `docker version` dan `docker-compose version`
5. Untuk Kubernetes, periksa dengan `kubectl cluster-info` 