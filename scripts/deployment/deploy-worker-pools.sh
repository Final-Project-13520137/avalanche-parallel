#!/bin/bash

# Deploy Avalanche Worker Pools to Kubernetes
# Deploy and manage worker pools with auto-scaling

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
MICROSERVICES_DIR="$ROOT_DIR/microservices"
K8S_DIR="$MICROSERVICES_DIR/k8s"

# Worker pools
WORKER_POOLS=(
    "consensus-worker"
    "validator-worker"
    "dag-state-worker"
)

# Function to print colored output
print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running"
        exit 1
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info > /dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if helm is installed (optional)
    if ! command -v helm &> /dev/null; then
        print_warning "Helm is not installed. Some features may not work."
    fi
    
    print_success "Prerequisites check passed"
}

# Build worker images
build_worker_images() {
    print_step "Building worker images..."
    
    cd "$MICROSERVICES_DIR"
    
    for worker in "${WORKER_POOLS[@]}"; do
        print_step "Building $worker image..."
        
        # Create Dockerfile for worker
        create_worker_dockerfile "$worker"
        
        # Build Docker image
        docker build -t "avalanche-$worker:latest" -f "workers/$worker/Dockerfile" .
        
        print_success "$worker image built successfully"
    done
    
    print_success "All worker images built"
}

# Create Dockerfile for worker
create_worker_dockerfile() {
    local worker=$1
    local worker_dir="$MICROSERVICES_DIR/workers/$worker"
    
    mkdir -p "$worker_dir"
    
    cat > "$worker_dir/Dockerfile" << EOF
# Multi-stage build for $worker
FROM golang:1.21-alpine AS builder

# Install dependencies
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the worker
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o $worker ./workers/$worker/cmd

# Final stage
FROM alpine:latest

# Install ca-certificates and curl for health checks
RUN apk --no-cache add ca-certificates curl

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/$worker .

# Create log directory
RUN mkdir -p /var/log

# Expose metrics port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost:8080/health || exit 1

# Run the worker
CMD ["./$worker"]
EOF
}

# Setup namespace and basic resources
setup_namespace() {
    print_step "Setting up Kubernetes namespace..."
    
    # Create namespace if not exists
    kubectl create namespace avalanche --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply basic configuration
    kubectl apply -f "$K8S_DIR/configmap.yaml"
    
    # Create worker-specific ConfigMap
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: worker-config
  namespace: avalanche
data:
  redis.conf: |
    bind 0.0.0.0
    port 6379
    save 900 1
    save 300 10
    save 60 10000
    stop-writes-on-bgsave-error yes
    rdbcompression yes
    rdbchecksum yes
    dbfilename dump.rdb
    dir /data
  
  validation.yaml: |
    validator:
      type: validation
      max_workers: 15
      task_timeout: "30s"
      batch_size: 100
      metrics_interval: "15s"
    
    validation:
      signature_check: true
      balance_check: true
      format_check: true
      max_transaction_size: 1048576
    
    queue:
      task_queue: "validation_tasks"
      result_queue: "validation_results"
      dead_letter_queue: "validation_failed"
      max_retries: 3
      retry_delay: "2s"
  
  dag-state.yaml: |
    dag_state:
      type: dag_state
      max_workers: 8
      task_timeout: "120s"
      batch_size: 25
      metrics_interval: "45s"
    
    dag:
      max_depth: 1000
      ancestry_cache_size: 10000
      confidence_threshold: 0.8
    
    state:
      batch_updates: true
      update_interval: "5s"
      snapshot_interval: "300s"
    
    queue:
      task_queue: "dag_state_tasks"
      result_queue: "dag_state_results"
      dead_letter_queue: "dag_state_failed"
      max_retries: 2
      retry_delay: "10s"
EOF
    
    print_success "Namespace and basic resources setup completed"
}

# Deploy Redis for message queue
deploy_redis() {
    print_step "Deploying Redis message queue..."
    
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: avalanche
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        command: ["redis-server"]
        args: ["/etc/redis/redis.conf"]
        volumeMounts:
        - name: redis-config
          mountPath: /etc/redis
        - name: redis-data
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: redis-config
        configMap:
          name: worker-config
          items:
          - key: redis.conf
            path: redis.conf
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: avalanche
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
  type: ClusterIP
EOF
    
    print_success "Redis deployed successfully"
}

# Deploy worker pools
deploy_worker_pools() {
    print_step "Deploying worker pools..."
    
    # Deploy consensus workers
    kubectl apply -f "$K8S_DIR/worker-pools/consensus-worker-deployment.yaml"
    
    # Deploy validator workers
    kubectl apply -f "$K8S_DIR/worker-pools/validator-worker-deployment.yaml"
    
    # Deploy DAG+State workers
    create_dag_state_deployment
    kubectl apply -f "$K8S_DIR/worker-pools/dag-state-worker-deployment.yaml"
    
    print_success "Worker pools deployed successfully"
}

# Create DAG+State worker deployment
create_dag_state_deployment() {
    cat > "$K8S_DIR/worker-pools/dag-state-worker-deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dag-state-worker-pool
  namespace: avalanche
  labels:
    app: dag-state-worker
    pool: dag-state
    component: worker
spec:
  replicas: 3
  selector:
    matchLabels:
      app: dag-state-worker
  template:
    metadata:
      labels:
        app: dag-state-worker
        pool: dag-state
        component: worker
    spec:
      containers:
      - name: dag-state-worker
        image: avalanche-dag-state-worker:latest
        ports:
        - containerPort: 8082
          name: metrics
        env:
        - name: WORKER_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: REDIS_URL
          value: "redis://redis:6379"
        - name: TASK_QUEUE
          value: "dag_state_tasks"
        - name: RESULT_QUEUE
          value: "dag_state_results"
        - name: MAX_WORKERS
          value: "8"
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            memory: "1Gi"
            cpu: "750m"
          limits:
            memory: "2Gi"
            cpu: "1500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8082
          initialDelaySeconds: 45
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /ready
            port: 8082
          initialDelaySeconds: 10
          periodSeconds: 10
        volumeMounts:
        - name: worker-config
          mountPath: /etc/worker
          readOnly: true
      volumes:
      - name: worker-config
        configMap:
          name: worker-config
      restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  name: dag-state-worker-service
  namespace: avalanche
spec:
  selector:
    app: dag-state-worker
  ports:
  - name: metrics
    port: 8082
    targetPort: 8082
  type: ClusterIP
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dag-state-worker-hpa
  namespace: avalanche
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dag-state-worker-pool
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 75
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 120
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 600
      policies:
      - type: Percent
        value: 25
        periodSeconds: 120
EOF
}

# Setup monitoring
setup_monitoring() {
    print_step "Setting up monitoring..."
    
    # Deploy Prometheus for worker metrics
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: avalanche
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus/'
        - '--web.console.libraries=/etc/prometheus/console_libraries'
        - '--web.console.templates=/etc/prometheus/consoles'
        - '--web.enable-lifecycle'
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        - name: prometheus-storage
          mountPath: /prometheus
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: avalanche
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: LoadBalancer
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: avalanche
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    
    scrape_configs:
    - job_name: 'consensus-workers'
      static_configs:
      - targets: ['consensus-worker-service:8080']
      metrics_path: /metrics
      scrape_interval: 30s
    
    - job_name: 'validator-workers'
      static_configs:
      - targets: ['validator-worker-service:8081']
      metrics_path: /metrics
      scrape_interval: 15s
    
    - job_name: 'dag-state-workers'
      static_configs:
      - targets: ['dag-state-worker-service:8082']
      metrics_path: /metrics
      scrape_interval: 45s
EOF
    
    print_success "Monitoring setup completed"
}

# Wait for deployments
wait_for_deployments() {
    print_step "Waiting for deployments to be ready..."
    
    # Wait for Redis
    kubectl wait --for=condition=available --timeout=300s deployment/redis -n avalanche
    
    # Wait for worker pools
    for worker in "${WORKER_POOLS[@]}"; do
        print_step "Waiting for $worker to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/${worker}-pool -n avalanche
    done
    
    print_success "All deployments are ready"
}

# Show deployment status
show_status() {
    print_step "Deployment Status:"
    echo ""
    
    # Show deployments
    echo "Deployments:"
    kubectl get deployments -n avalanche
    echo ""
    
    # Show pods
    echo "Pods:"
    kubectl get pods -n avalanche
    echo ""
    
    # Show services
    echo "Services:"
    kubectl get services -n avalanche
    echo ""
    
    # Show HPA
    echo "Horizontal Pod Autoscalers:"
    kubectl get hpa -n avalanche
    echo ""
    
    # Show worker metrics endpoints
    echo "Worker Metrics Endpoints:"
    echo "- Consensus Workers: http://localhost:8080/metrics"
    echo "- Validator Workers: http://localhost:8081/metrics"
    echo "- DAG+State Workers: http://localhost:8082/metrics"
    echo ""
    
    # Show Prometheus
    echo "Monitoring:"
    echo "- Prometheus: http://localhost:9090"
}

# Test worker pools
test_worker_pools() {
    print_step "Testing worker pools..."
    
    # Port forward for testing
    kubectl port-forward svc/consensus-worker-service 8080:8080 -n avalanche &
    CONSENSUS_PF_PID=$!
    
    kubectl port-forward svc/validator-worker-service 8081:8081 -n avalanche &
    VALIDATOR_PF_PID=$!
    
    sleep 10
    
    # Test consensus workers
    if curl -s http://localhost:8080/health > /dev/null; then
        print_success "Consensus workers are healthy"
    else
        print_error "Consensus workers health check failed"
    fi
    
    # Test validator workers
    if curl -s http://localhost:8081/health > /dev/null; then
        print_success "Validator workers are healthy"
    else
        print_error "Validator workers health check failed"
    fi
    
    # Cleanup port forwards
    kill $CONSENSUS_PF_PID $VALIDATOR_PF_PID 2>/dev/null || true
    
    print_success "Worker pool testing completed"
}

# Scale workers
scale_workers() {
    local worker_type=$1
    local replicas=$2
    
    if [ -z "$worker_type" ] || [ -z "$replicas" ]; then
        print_error "Usage: scale_workers <worker_type> <replicas>"
        return 1
    fi
    
    print_step "Scaling $worker_type to $replicas replicas..."
    
    kubectl scale deployment ${worker_type}-pool --replicas=$replicas -n avalanche
    
    print_success "$worker_type scaled to $replicas replicas"
}

# Main execution
main() {
    local action="deploy"
    local worker_type=""
    local replicas=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            deploy)
                action="deploy"
                shift
                ;;
            test)
                action="test"
                shift
                ;;
            status)
                action="status"
                shift
                ;;
            scale)
                action="scale"
                worker_type=$2
                replicas=$3
                shift 3
                ;;
            clean)
                action="clean"
                shift
                ;;
            --help)
                echo "Usage: $0 [action] [options]"
                echo "Actions:"
                echo "  deploy    Deploy all worker pools (default)"
                echo "  test      Test worker pool health"
                echo "  status    Show deployment status"
                echo "  scale     Scale specific worker pool"
                echo "  clean     Clean up all resources"
                echo ""
                echo "Examples:"
                echo "  $0 deploy"
                echo "  $0 scale consensus-worker 5"
                echo "  $0 test"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    case $action in
        deploy)
            echo "🚀 Deploying Avalanche Worker Pools..."
            check_prerequisites
            build_worker_images
            setup_namespace
            deploy_redis
            deploy_worker_pools
            setup_monitoring
            wait_for_deployments
            show_status
            print_success "✅ Worker pools deployment completed!"
            ;;
        test)
            test_worker_pools
            ;;
        status)
            show_status
            ;;
        scale)
            scale_workers "$worker_type" "$replicas"
            ;;
        clean)
            print_step "Cleaning up worker pools..."
            kubectl delete namespace avalanche --ignore-not-found=true
            print_success "Cleanup completed"
            ;;
    esac
}

# Run main function
main "$@" 