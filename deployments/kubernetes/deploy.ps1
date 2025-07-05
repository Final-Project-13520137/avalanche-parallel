# Avalanche Parallel Kubernetes Deployment Script for Windows
param(
    [switch]$Build,
    [switch]$Push,
    [string]$Registry = "docker.io/your-registry",
    [string]$Tag = "latest",
    [string]$Context = "",
    [switch]$Help
)

# Configuration
$Namespace = "avalanche-parallel"
$ErrorActionPreference = "Stop"

# Colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# Show help
if ($Help) {
    Write-Host @"
Usage: .\deploy.ps1 [OPTIONS]
Options:
  -Build         Build Docker images
  -Push          Push images to registry (implies -Build)
  -Registry      Docker registry (default: docker.io/your-registry)
  -Tag           Image tag (default: latest)
  -Context       Kubernetes context to use
  -Help          Show this help message

Examples:
  .\deploy.ps1 -Build
  .\deploy.ps1 -Build -Push -Registry myregistry.io -Tag v1.0.0
"@
    exit 0
}

# Check prerequisites
function Check-Prerequisites {
    Write-ColorOutput Yellow "Checking prerequisites..."
    
    # Check kubectl
    if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-ColorOutput Red "kubectl is not installed. Please install kubectl first."
        exit 1
    }
    
    # Check docker
    if ($Build -and !(Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-ColorOutput Red "Docker is not installed. Please install Docker first."
        exit 1
    }
    
    Write-ColorOutput Green "Prerequisites check passed!"
}

# Build Docker images
function Build-Images {
    if ($Build) {
        Write-ColorOutput Yellow "Building Docker images..."
        
        # Build main node image
        docker build -f ../docker/Dockerfile.main-node -t "${Registry}/avalanche-main-node:${Tag}" ../..
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        
        # Build worker image
        docker build -f ../docker/Dockerfile.worker-node -t "${Registry}/avalanche-worker:${Tag}" ../..
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        
        if ($Push) {
            Write-ColorOutput Yellow "Pushing images to registry..."
            docker push "${Registry}/avalanche-main-node:${Tag}"
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            
            docker push "${Registry}/avalanche-worker:${Tag}"
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
        
        Write-ColorOutput Green "Docker images built successfully!"
    }
}

# Update kustomization
function Update-Kustomization {
    Write-ColorOutput Yellow "Updating kustomization with image tags..."
    
    $content = Get-Content -Path "kustomization.yaml" -Raw
    $content = $content -replace "avalanche-parallel/main-node", "${Registry}/avalanche-main-node"
    $content = $content -replace "avalanche-parallel/worker", "${Registry}/avalanche-worker"
    $content = $content -replace "newTag: .*", "newTag: ${Tag}"
    
    Set-Content -Path "kustomization.yaml" -Value $content
}

# Deploy to Kubernetes
function Deploy-ToKubernetes {
    Write-ColorOutput Yellow "Deploying to Kubernetes..."
    
    # Set context if provided
    if ($Context) {
        kubectl config use-context $Context
    }
    
    # Create namespace if it doesn't exist
    kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply configurations using kustomize
    kubectl apply -k .
    
    Write-ColorOutput Green "Deployment completed!"
}

# Wait for deployments
function Wait-ForReady {
    Write-ColorOutput Yellow "Waiting for deployments to be ready..."
    
    # Wait for RabbitMQ
    kubectl wait --for=condition=ready pod -l app=rabbitmq -n $Namespace --timeout=300s
    
    # Wait for main node
    kubectl wait --for=condition=ready pod -l app=avalanche-main-node -n $Namespace --timeout=300s
    
    # Wait for workers
    kubectl wait --for=condition=ready pod -l app=avalanche-worker -n $Namespace --timeout=300s
    
    # Wait for monitoring
    kubectl wait --for=condition=ready pod -l app=prometheus -n $Namespace --timeout=300s
    kubectl wait --for=condition=ready pod -l app=grafana -n $Namespace --timeout=300s
    
    Write-ColorOutput Green "All deployments are ready!"
}

# Show access information
function Show-AccessInfo {
    Write-ColorOutput Green "`n=== Access Information ==="
    
    # Get NodePort services
    $apiPort = kubectl get svc avalanche-api-gateway -n $Namespace -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}'
    $grafanaPort = kubectl get svc grafana -n $Namespace -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}'
    
    # Get node IP
    $nodeIP = kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}'
    if ([string]::IsNullOrEmpty($nodeIP)) {
        $nodeIP = kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'
    }
    
    Write-ColorOutput Green "API Gateway: http://${nodeIP}:${apiPort}"
    Write-ColorOutput Green "Grafana: http://${nodeIP}:${grafanaPort} (admin/avalanche123)"
    Write-ColorOutput Green "`nTo check worker scaling:"
    Write-ColorOutput Yellow "kubectl get hpa -n $Namespace"
    Write-ColorOutput Green "`nTo scale workers manually:"
    Write-ColorOutput Yellow "kubectl scale deployment avalanche-worker -n $Namespace --replicas=10"
}

# Main execution
Write-ColorOutput Green "=== Avalanche Parallel Kubernetes Deployment ==="

Check-Prerequisites
Build-Images
Update-Kustomization
Deploy-ToKubernetes
Wait-ForReady
Show-AccessInfo

Write-ColorOutput Green "`n=== Deployment completed successfully! ===" 