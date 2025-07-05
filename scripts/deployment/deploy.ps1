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
    
    # Check Kubernetes cluster connectivity
    Write-ColorOutput Yellow "Checking Kubernetes cluster connectivity..."
    try {
        kubectl cluster-info --request-timeout=5s 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput Red "No Kubernetes cluster found or cluster is not accessible."
            Write-ColorOutput Yellow "Please run one of the following to setup a cluster:"
            Write-ColorOutput Yellow "  .\setup-k8s.ps1 -Provider docker-desktop"
            Write-ColorOutput Yellow "  .\setup-k8s.ps1 -Provider kind"
            Write-ColorOutput Yellow "  .\setup-k8s.ps1 -Provider minikube"
            Write-ColorOutput Yellow ""
            Write-ColorOutput Yellow "Or if you want to deploy only Docker images without Kubernetes:"
            Write-ColorOutput Yellow "  docker-compose -f ../../config/docker-compose.yml up -d"
            exit 1
        }
        Write-ColorOutput Green "Kubernetes cluster is accessible!"
    } catch {
        Write-ColorOutput Red "Failed to connect to Kubernetes cluster."
        Write-ColorOutput Yellow "Please setup a cluster first using .\setup-k8s.ps1"
        exit 1
    }
    
    Write-ColorOutput Green "Prerequisites check passed!"
}

# Build Docker images
function Build-Images {
    if ($Build) {
        Write-ColorOutput Yellow "Building Docker images..."
        
        # Ensure go.mod.docker exists
        if (!(Test-Path "../../go.mod.docker")) {
            Write-ColorOutput Red "go.mod.docker not found. Creating it..."
            # Create go.mod.docker from go.mod by removing incompatible lines
            $content = Get-Content "../../go.mod" | ForEach-Object { 
                $_ -replace "go 1\.23\.9", "go 1.21" 
            } | Where-Object { $_ -notmatch "toolchain" }
            Set-Content -Path "../../go.mod.docker" -Value $content
        }
        
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
    
    # Apply configurations using kustomize with validation disabled for local clusters
    Write-ColorOutput Yellow "Applying Kubernetes configurations..."
    try {
        kubectl apply -k . --validate=false
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput Yellow "Retrying with individual file deployment..."
            
            # Apply files individually if kustomize fails
            $files = @(
                "00-namespace.yaml",
                "01-message-queue.yaml", 
                "02-main-node.yaml",
                "03-worker-deployment.yaml",
                "04-api-gateway.yaml",
                "05-monitoring.yaml",
                "06-grafana-dashboard.yaml"
            )
            
            foreach ($file in $files) {
                Write-ColorOutput Yellow "Applying $file..."
                kubectl apply -f $file --validate=false
            }
        }
    } catch {
        Write-ColorOutput Red "Deployment failed: $_"
        Write-ColorOutput Yellow "Trying alternative deployment method..."
        
        # Fallback to manual deployment
        kubectl apply -f 00-namespace.yaml --validate=false
        kubectl apply -f 01-message-queue.yaml --validate=false
        kubectl apply -f 02-main-node.yaml --validate=false
        kubectl apply -f 03-worker-deployment.yaml --validate=false
        kubectl apply -f 04-api-gateway.yaml --validate=false
        kubectl apply -f 05-monitoring.yaml --validate=false
        kubectl apply -f 06-grafana-dashboard.yaml --validate=false
    }
    
    Write-ColorOutput Green "Deployment completed!"
    
    # Install metrics server for HPA to work
    Install-MetricsServer
}

# Install metrics server
function Install-MetricsServer {
    Write-ColorOutput Yellow "Checking metrics server..."
    
    # Check if metrics server is already running
    try {
        kubectl get deployment metrics-server -n kube-system 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput Green "Metrics server already installed"
            return
        }
    } catch {
        # Continue with installation
    }
    
    Write-ColorOutput Yellow "Installing metrics server..."
    
    # Try to use local manifest first
    if (Test-Path "metrics-server.yaml") {
        Write-ColorOutput Yellow "Using local metrics-server manifest..."
        kubectl apply -f metrics-server.yaml --validate=false
    } else {
        Write-ColorOutput Yellow "Installing metrics server from remote..."
        
        # Apply the complete metrics server from remote
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --validate=false
        
        # Wait for deployment to exist
        Start-Sleep -Seconds 10
        
        # Patch the deployment with correct image and args
        $patchJson = '{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp","--secure-port=4443","--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname","--kubelet-use-node-status-port","--metric-resolution=15s","--kubelet-insecure-tls"],"image":"registry.k8s.io/metrics-server/metrics-server:v0.7.0"}]}}}}'
        
        kubectl patch deployment metrics-server -n kube-system --type=merge -p $patchJson --validate=false
    }
    
    # Wait for metrics server to be ready
    Write-ColorOutput Yellow "Waiting for metrics server to be ready..."
    try {
        kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
    } catch {
        Write-ColorOutput Yellow "Metrics server may take a while to be ready, continuing..."
    }
    
    Write-ColorOutput Green "Metrics server installation completed"
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