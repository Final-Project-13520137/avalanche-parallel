# Deploy to Kubernetes for Avalanche Parallel Processing
param(
    [switch]$Build = $false,
    [string]$Registry = "localhost:5000",
    [string]$Namespace = "avalanche-parallel",
    [string]$KubeConfig = "$HOME/.kube/config"
)

Write-Host "🚀 Deploying Avalanche Parallel Processing to Kubernetes..." -ForegroundColor Green

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check kubectl
if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ kubectl not found. Please install kubectl." -ForegroundColor Red
    exit 1
}

# Check kubeconfig
if (!(Test-Path $KubeConfig)) {
    Write-Host "❌ kubeconfig not found at $KubeConfig" -ForegroundColor Red
    exit 1
}

# Build and push images if requested
if ($Build) {
    Write-Host "🔨 Building and pushing Docker images..." -ForegroundColor Yellow
    
    # Build images
    docker-compose -f docker-compose.worker-pools.yml build
    
    # Tag images
    docker tag microservices-consensus-worker:latest "$Registry/consensus-worker:latest"
    docker tag microservices-validator-worker:latest "$Registry/validator-worker:latest"
    docker tag microservices-dag-state-worker:latest "$Registry/dag-state-worker:latest"
    
    # Push images
    docker push "$Registry/consensus-worker:latest"
    docker push "$Registry/validator-worker:latest"
    docker push "$Registry/dag-state-worker:latest"
}

# Create namespace if not exists
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

# Apply Kubernetes manifests
Write-Host "📦 Applying Kubernetes manifests..." -ForegroundColor Yellow

# Apply in order
$manifests = @(
    "k8s/namespace.yaml",
    "k8s/configmap.yaml",
    "k8s/secret.yaml",
    "k8s/redis.yaml",
    "k8s/postgres.yaml",
    "k8s/consensus-worker.yaml",
    "k8s/validator-worker.yaml",
    "k8s/dag-state-worker.yaml",
    "k8s/api-gateway.yaml",
    "k8s/monitoring.yaml"
)

foreach ($manifest in $manifests) {
    if (Test-Path $manifest) {
        Write-Host "Applying $manifest..." -ForegroundColor Cyan
        kubectl apply -f $manifest -n $Namespace
    }
}

# Wait for pods to be ready
Write-Host "⏳ Waiting for pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod --all -n $Namespace --timeout=300s

# Show status
Write-Host "`n📊 Deployment Status:" -ForegroundColor Green
kubectl get pods -n $Namespace

Write-Host "`n✅ Deployment completed!" -ForegroundColor Green
Write-Host @"
🔍 Next steps:
1. Check pod status: kubectl get pods -n $Namespace
2. View logs: kubectl logs -f -n $Namespace <pod-name>
3. Monitor metrics: kubectl port-forward -n $Namespace svc/grafana 3000:3000
"@ -ForegroundColor Cyan 