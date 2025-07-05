# Avalanche Parallel Kubernetes Setup Script
param(
    [ValidateSet("docker-desktop", "kind", "minikube")]
    [string]$Provider = "docker-desktop",
    [string]$ClusterName = "avalanche-parallel",
    [switch]$Help
)

# Colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

if ($Help) {
    Write-Host @"
Avalanche Parallel Kubernetes Setup Script

Usage: .\setup-k8s.ps1 [OPTIONS]

Options:
  -Provider        Kubernetes provider (docker-desktop, kind, minikube)
  -ClusterName     Name for the cluster (default: avalanche-parallel)
  -Help            Show this help message

Examples:
  .\setup-k8s.ps1 -Provider docker-desktop
  .\setup-k8s.ps1 -Provider kind -ClusterName my-cluster
  .\setup-k8s.ps1 -Provider minikube

Requirements:
  - Docker Desktop (for docker-desktop provider)
  - kind (for kind provider): https://kind.sigs.k8s.io/docs/user/quick-start/
  - minikube (for minikube provider): https://minikube.sigs.k8s.io/docs/start/
"@
    exit 0
}

function Test-Command($Command) {
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Setup-DockerDesktop {
    Write-ColorOutput Green "Setting up Docker Desktop Kubernetes..."
    
    if (!(Test-Command "docker")) {
        Write-ColorOutput Red "Docker not found. Please install Docker Desktop first."
        Write-ColorOutput Yellow "Download from: https://www.docker.com/products/docker-desktop/"
        exit 1
    }
    
    Write-ColorOutput Yellow "Please enable Kubernetes in Docker Desktop:"
    Write-ColorOutput Yellow "1. Open Docker Desktop"
    Write-ColorOutput Yellow "2. Go to Settings > Kubernetes"
    Write-ColorOutput Yellow "3. Check 'Enable Kubernetes'"
    Write-ColorOutput Yellow "4. Click 'Apply & Restart'"
    Write-ColorOutput Yellow ""
    Write-ColorOutput Yellow "Press any key after enabling Kubernetes..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Wait for cluster to be ready
    $maxRetries = 30
    $retryCount = 0
    
    do {
        $retryCount++
        Write-ColorOutput Yellow "Waiting for Kubernetes cluster... (attempt $retryCount/$maxRetries)"
        
        try {
            kubectl cluster-info --request-timeout=5s 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput Green "Kubernetes cluster is ready!"
                kubectl config use-context docker-desktop
                return
            }
        } catch {
            # Ignore error
        }
        
        Start-Sleep -Seconds 10
    } while ($retryCount -lt $maxRetries)
    
    Write-ColorOutput Red "Failed to connect to Kubernetes cluster. Please check Docker Desktop settings."
    exit 1
}

function Setup-Kind {
    Write-ColorOutput Green "Setting up kind cluster..."
    
    if (!(Test-Command "kind")) {
        Write-ColorOutput Red "kind not found. Installing kind..."
        
        # Install kind using Go
        if (Test-Command "go") {
            go install sigs.k8s.io/kind@v0.20.0
        } else {
            Write-ColorOutput Red "Go not found. Please install kind manually:"
            Write-ColorOutput Yellow "https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
            exit 1
        }
    }
    
    # Create kind cluster config
    $kindConfig = @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 30080
    protocol: TCP
  - containerPort: 443
    hostPort: 30443
    protocol: TCP
  - containerPort: 30300
    hostPort: 30300
    protocol: TCP
- role: worker
- role: worker
"@
    
    Set-Content -Path "kind-config.yaml" -Value $kindConfig
    
    # Delete existing cluster if exists
    kind delete cluster --name $ClusterName 2>$null
    
    # Create new cluster
    Write-ColorOutput Yellow "Creating kind cluster '$ClusterName'..."
    kind create cluster --name $ClusterName --config kind-config.yaml
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput Green "Kind cluster '$ClusterName' created successfully!"
        kubectl config use-context "kind-$ClusterName"
        
        # Install ingress controller
        Write-ColorOutput Yellow "Installing NGINX Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
        
        # Wait for ingress controller
        Write-ColorOutput Yellow "Waiting for ingress controller to be ready..."
        kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
    } else {
        Write-ColorOutput Red "Failed to create kind cluster"
        exit 1
    }
}

function Setup-Minikube {
    Write-ColorOutput Green "Setting up minikube cluster..."
    
    if (!(Test-Command "minikube")) {
        Write-ColorOutput Red "minikube not found. Please install minikube:"
        Write-ColorOutput Yellow "https://minikube.sigs.k8s.io/docs/start/"
        exit 1
    }
    
    # Stop existing cluster if running
    minikube stop -p $ClusterName 2>$null
    minikube delete -p $ClusterName 2>$null
    
    # Start new cluster
    Write-ColorOutput Yellow "Starting minikube cluster '$ClusterName'..."
    minikube start -p $ClusterName --nodes=3 --driver=docker --memory=4096 --cpus=2
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput Green "Minikube cluster '$ClusterName' started successfully!"
        kubectl config use-context $ClusterName
        
        # Enable addons
        Write-ColorOutput Yellow "Enabling minikube addons..."
        minikube addons enable ingress -p $ClusterName
        minikube addons enable metrics-server -p $ClusterName
    } else {
        Write-ColorOutput Red "Failed to start minikube cluster"
        exit 1
    }
}

function Verify-Cluster {
    Write-ColorOutput Yellow "Verifying cluster setup..."
    
    # Check cluster info
    kubectl cluster-info
    
    # Check nodes
    Write-ColorOutput Yellow "Cluster nodes:"
    kubectl get nodes
    
    # Check if metrics server is available
    Write-ColorOutput Yellow "Checking metrics server..."
    kubectl top nodes 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Yellow "Metrics server not available. Installing..."
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        
        # Patch metrics server for local clusters
        kubectl patch deployment metrics-server -n kube-system --type='merge' -p='{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp","--secure-port=4443","--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname","--kubelet-use-node-status-port","--metric-resolution=15s","--kubelet-insecure-tls"]}]}}}}'
    }
    
    Write-ColorOutput Green "Cluster verification completed!"
}

# Main execution
Write-ColorOutput Green "=== Avalanche Parallel Kubernetes Setup ==="
Write-ColorOutput Yellow "Provider: $Provider"
Write-ColorOutput Yellow "Cluster Name: $ClusterName"
Write-ColorOutput Yellow ""

switch ($Provider) {
    "docker-desktop" { Setup-DockerDesktop }
    "kind" { Setup-Kind }
    "minikube" { Setup-Minikube }
}

Verify-Cluster

Write-ColorOutput Green ""
Write-ColorOutput Green "=== Setup completed successfully! ==="
Write-ColorOutput Green "You can now deploy Avalanche Parallel using:"
Write-ColorOutput Yellow ".\deploy.ps1 -Build -Registry localhost:5000" 