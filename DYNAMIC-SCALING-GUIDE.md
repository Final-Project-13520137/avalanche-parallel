# Avalanche Parallel - Dynamic Node Scaling Guide

Panduan lengkap untuk scaling node secara dinamis dengan automatic port allocation.

## 🎯 Overview

Dynamic Node Scaling memungkinkan Anda untuk:
- **Scale Up/Down** nodes secara otomatis
- **Auto Port Allocation** - sistem otomatis assign port yang tersedia
- **Horizontal Scaling** - tambah/kurangi nodes sesuai kebutuhan
- **Zero Downtime** - scaling tanpa mengganggu nodes yang sudah running

## 🚀 Quick Start

### 1. Setup Permissions
```bash
# Make scripts executable
chmod +x make-executable.sh && ./make-executable.sh
```

### 2. Docker Dynamic Scaling
```bash
# Start base system
./deploy-docker.sh --build --workers 1

# Scale up to 5 workers
./docker-dynamic-scaler.sh scale-up --type worker --replicas 5

# Check status
./docker-dynamic-scaler.sh status
```

### 3. Kubernetes Dynamic Scaling
```bash
# Setup cluster and deploy
./setup-k8s.sh --provider kind
cd deployments/kubernetes && ./deploy.sh --build

# Scale up workers
./dynamic-node-scaler.sh scale-up --type worker --replicas 5

# Check status
./dynamic-node-scaler.sh status
```

## 📋 Available Commands

### Docker Dynamic Scaler (`./docker-dynamic-scaler.sh`)

#### Scale Operations
```bash
# Scale up workers to 5 replicas
./docker-dynamic-scaler.sh scale-up --type worker --replicas 5

# Scale down workers to 2 replicas
./docker-dynamic-scaler.sh scale-down --type worker --replicas 2

# Scale both main and worker nodes
./docker-dynamic-scaler.sh scale-up --type both --replicas 3
```

#### Individual Node Operations
```bash
# Add single worker (auto-assign port)
./docker-dynamic-scaler.sh add-node --type worker

# Add worker with specific port
./docker-dynamic-scaler.sh add-node --type worker --port 9662

# Add main node
./docker-dynamic-scaler.sh add-node --type main

# Remove specific node
./docker-dynamic-scaler.sh remove-node --type worker --port 9662
```

#### Monitoring & Management
```bash
# List all nodes
./docker-dynamic-scaler.sh list

# Show detailed status
./docker-dynamic-scaler.sh status

# Stop all dynamic nodes (keeps original docker-compose nodes)
./docker-dynamic-scaler.sh stop-all
```

### Kubernetes Dynamic Scaler (`./dynamic-node-scaler.sh`)

#### Scale Operations
```bash
# Scale up workers to 5 replicas
./dynamic-node-scaler.sh scale-up --type worker --replicas 5

# Scale down workers to 2 replicas
./dynamic-node-scaler.sh scale-down --type worker --replicas 2

# Scale both main-node and worker
./dynamic-node-scaler.sh scale-up --type both --replicas 3
```

#### Individual Node Operations
```bash
# Add single worker (auto-assign port)
./dynamic-node-scaler.sh add-node --type worker

# Add worker with specific port
./dynamic-node-scaler.sh add-node --type worker --port 9662

# Add main node
./dynamic-node-scaler.sh add-node --type main-node

# Remove specific node
./dynamic-node-scaler.sh remove-node --type worker --port 9662
```

#### Monitoring & Management
```bash
# List all nodes
./dynamic-node-scaler.sh list

# Show detailed status
./dynamic-node-scaler.sh status
```

## 🔢 Port Allocation System

### Automatic Port Assignment
- **Main Nodes**: 9650, 9660, 9670, 9680, 9690...
- **Worker Nodes**: 9652, 9662, 9672, 9682, 9692...
- **P2P Ports**: 9651, 9661, 9671, 9681, 9691...

### Port Increment Pattern
- Base ports: Main=9650, Worker=9652
- Increment: +10 for each new node
- Auto-detection of available ports
- Conflict resolution

### Example Port Layout
```
Node Type    | Instance | API Port | P2P Port | Status
-------------|----------|----------|----------|--------
main         | 1        | 9650     | 9651     | Running
worker       | 1        | 9652     | 9651     | Running
main         | 2        | 9660     | 9661     | Running
worker       | 2        | 9662     | 9661     | Running
worker       | 3        | 9672     | 9671     | Running
```

## 📊 Monitoring & Status

### Check Current Status
```bash
# Docker
./docker-dynamic-scaler.sh status

# Kubernetes
./dynamic-node-scaler.sh status
```

### Expected Output
```
=== Avalanche Parallel Cluster Status ===
Main Nodes: 2
Worker Nodes: 5
Running Pods: 7

Port Allocation:
avalanche-main-9650     NodePort   9650,9651
avalanche-main-9660     NodePort   9660,9661
avalanche-worker-9652   NodePort   9652,9651
avalanche-worker-9662   NodePort   9662,9661
avalanche-worker-9672   NodePort   9672,9671

Resource Usage:
NAME                    CPU(cores)   MEMORY(bytes)
avalanche-main-9650     100m         512Mi
avalanche-worker-9652   50m          256Mi
```

## 🔄 Scaling Scenarios

### Scenario 1: Traffic Spike
```bash
# Current: 2 workers, need to handle more load
./docker-dynamic-scaler.sh scale-up --type worker --replicas 10

# Monitor performance
./docker-dynamic-scaler.sh status
docker stats
```

### Scenario 2: Cost Optimization
```bash
# Scale down during low traffic
./docker-dynamic-scaler.sh scale-down --type worker --replicas 2

# Keep monitoring
./docker-dynamic-scaler.sh status
```

### Scenario 3: High Availability
```bash
# Add redundant main nodes
./dynamic-node-scaler.sh scale-up --type main-node --replicas 3

# Scale workers for load distribution
./dynamic-node-scaler.sh scale-up --type worker --replicas 8
```

### Scenario 4: Development Testing
```bash
# Add single node for testing
./docker-dynamic-scaler.sh add-node --type worker --port 9999

# Test specific functionality
curl http://localhost:9999/health

# Remove test node
./docker-dynamic-scaler.sh remove-node --type worker --port 9999
```

## 🛠️ Advanced Usage

### Custom Port Assignment
```bash
# Add worker with specific port
./docker-dynamic-scaler.sh add-node --type worker --port 9700

# Add main node with specific port
./dynamic-node-scaler.sh add-node --type main-node --port 9800
```

### Batch Operations
```bash
# Scale up multiple types
./dynamic-node-scaler.sh scale-up --type both --replicas 5

# This will create:
# - 5 main-node instances
# - 5 worker instances
```

### Resource Management
```bash
# Check resource usage
docker stats $(docker ps --filter "name=avalanche" --format "{{.Names}}")

# Or for Kubernetes
kubectl top pods -n avalanche-parallel
```

## 🔧 Troubleshooting

### Port Conflicts
```bash
# Check what's using a port
netstat -tulpn | grep 9652
lsof -i :9652

# Use different port
./docker-dynamic-scaler.sh add-node --type worker --port 9700
```

### Container Issues
```bash
# Check container logs
docker logs avalanche-worker-9662

# Restart specific container
docker restart avalanche-worker-9662

# Remove and recreate
./docker-dynamic-scaler.sh remove-node --type worker --port 9662
./docker-dynamic-scaler.sh add-node --type worker --port 9662
```

### Kubernetes Issues
```bash
# Check pod status
kubectl get pods -n avalanche-parallel -l instance=worker-9662

# Check logs
kubectl logs -n avalanche-parallel deployment/avalanche-worker-9662

# Describe for details
kubectl describe pod -n avalanche-parallel -l instance=worker-9662
```

### Network Issues
```bash
# Check Docker network
docker network ls
docker network inspect avalanche-parallel_avalanche-network

# For Kubernetes, check services
kubectl get svc -n avalanche-parallel
```

## 📈 Performance Guidelines

### Scaling Recommendations
- **Light Load**: 1 main + 2-3 workers
- **Medium Load**: 1-2 main + 5-8 workers  
- **Heavy Load**: 2-3 main + 10-20 workers
- **Enterprise**: 3+ main + 20+ workers

### Resource Planning
- **Main Node**: 1-2 CPU cores, 1-2GB RAM per instance
- **Worker Node**: 0.5-1 CPU cores, 512MB-1GB RAM per instance
- **Network**: Ensure sufficient bandwidth for P2P communication

### Monitoring Metrics
- CPU usage per node
- Memory consumption
- Network I/O
- Transaction throughput
- Response times

## 🚀 Best Practices

1. **Gradual Scaling**: Scale incrementally, not dramatically
2. **Monitor First**: Always check status before and after scaling
3. **Resource Limits**: Set appropriate resource limits in production
4. **Health Checks**: Ensure all nodes are healthy before adding load
5. **Backup Strategy**: Keep configuration backups
6. **Testing**: Test scaling in development environment first

## 🔗 Integration Examples

### With Load Balancer
```bash
# Scale workers behind load balancer
./docker-dynamic-scaler.sh scale-up --type worker --replicas 5

# Configure your load balancer to include:
# - http://localhost:9652
# - http://localhost:9662  
# - http://localhost:9672
# - http://localhost:9682
# - http://localhost:9692
```

### With Monitoring
```bash
# Scale and monitor
./dynamic-node-scaler.sh scale-up --type worker --replicas 5
kubectl top pods -n avalanche-parallel

# Check metrics in Grafana
# http://localhost:30300
```

### With CI/CD
```bash
# In deployment script
./docker-dynamic-scaler.sh scale-up --type worker --replicas ${WORKER_COUNT:-3}
./docker-dynamic-scaler.sh status
```

Dengan dynamic scaling ini, Anda dapat:
- ✅ Scale nodes sesuai kebutuhan traffic
- ✅ Port allocation otomatis tanpa konflik
- ✅ Zero downtime scaling
- ✅ Resource optimization
- ✅ High availability setup
- ✅ Easy monitoring dan management 