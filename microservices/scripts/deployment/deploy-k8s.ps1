# Script for deploying Avalanche Parallel Processing to Kubernetes

param(
    [switch]$Build,
    [string]$Registry = "localhost:5000",
    [string]$Namespace = "avalanche-parallel",
    [switch]$Force
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Get-Item $ScriptDir).Parent.Parent.FullName

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "🔍 Checking prerequisites..." -ForegroundColor Cyan

    # Check Docker
    try {
        docker info > $null 2>&1
    }
    catch {
        Write-Host "❌ Docker is not running" -ForegroundColor Red
        exit 1
    }

    # Check kubectl
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Host "❌ kubectl not found. Please install kubectl" -ForegroundColor Red
        exit 1
    }

    # Check if registry is accessible
    try {
        if ($Registry -eq "localhost:5000") {
            $response = Invoke-WebRequest "http://$Registry/v2/" -UseBasicParsing
            if ($response.StatusCode -ne 200) {
                throw "Registry not accessible"
            }
        }
    }
    catch {
        Write-Host "❌ Local registry not accessible. Start it with: docker run -d -p 5000:5000 --name registry registry:2" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ Prerequisites check passed" -ForegroundColor Green
}

# Function to build and push Docker images
function Build-Images {
    Write-Host "🔨 Building Docker images..." -ForegroundColor Cyan

    $services = @("consensus-worker", "validator-worker", "dag-state-worker")
    $buildContext = Join-Path $ProjectRoot "workers"

    foreach ($service in $services) {
        $dockerfile = Join-Path $buildContext "$service/Dockerfile"
        $tag = "$Registry/$service`:latest"

        Write-Host "Building $service..." -ForegroundColor Cyan
        docker build -t $tag -f $dockerfile $buildContext
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to build $service" -ForegroundColor Red
            exit 1
        }

        Write-Host "Pushing $service to registry..." -ForegroundColor Cyan
        docker push $tag
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to push $service" -ForegroundColor Red
            exit 1
        }
    }

    Write-Host "✅ All images built and pushed successfully" -ForegroundColor Green
}

# Function to apply Kubernetes manifests
function Apply-Manifests {
    Write-Host "📦 Applying Kubernetes manifests..." -ForegroundColor Cyan

    # Create or update namespace
    kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

    # Apply ConfigMap
    $configMapPath = Join-Path $ProjectRoot "k8s/configmap.yaml"
    Write-Host "Applying ConfigMap..." -ForegroundColor Cyan
    kubectl apply -f $configMapPath -n $Namespace

    # Apply worker deployments
    $k8sPath = Join-Path $ProjectRoot "k8s/worker-pools"
    Get-ChildItem $k8sPath -Filter "*-deployment.yaml" | ForEach-Object {
        Write-Host "Applying $($_.Name)..." -ForegroundColor Cyan
        
        # Replace registry in deployment file
        $content = Get-Content $_.FullName -Raw
        $content = $content.Replace("localhost:5000", $Registry)
        $content = $content.Replace("namespace: avalanche", "namespace: $Namespace")
        
        # Apply using temporary file
        $tempFile = New-TemporaryFile
        $content | Set-Content $tempFile
        kubectl apply -f $tempFile -n $Namespace
        Remove-Item $tempFile
    }

    Write-Host "✅ Kubernetes manifests applied successfully" -ForegroundColor Green
}

# Function to wait for pods
function Wait-ForPods {
    Write-Host "⏳ Waiting for pods to be ready..." -ForegroundColor Cyan
    
    $timeout = 300 # 5 minutes
    $elapsed = 0
    $interval = 5

    while ($elapsed -lt $timeout) {
        $pods = kubectl get pods -n $Namespace -o json | ConvertFrom-Json
        $allReady = $true
        
        foreach ($pod in $pods.items) {
            $name = $pod.metadata.name
            $status = $pod.status.phase
            $ready = $pod.status.containerStatuses.ready -contains $false

            if ($status -ne "Running" -or $ready) {
                $allReady = $false
                break
            }
        }

        if ($allReady) {
            Write-Host "✅ All pods are ready" -ForegroundColor Green
            return
        }

        Start-Sleep -Seconds $interval
        $elapsed += $interval
    }

    Write-Host "❌ Timeout waiting for pods to be ready" -ForegroundColor Red
    exit 1
}

# Main execution
Write-Host "🚀 Deploying Avalanche Parallel Processing to Kubernetes..." -ForegroundColor Cyan

# Check prerequisites
Test-Prerequisites

# Build and push images if requested
if ($Build) {
    Build-Images
}

# Apply Kubernetes manifests
Apply-Manifests

# Wait for pods to be ready
Wait-ForPods

# Show deployment status
Write-Host "`n📊 Deployment Status:" -ForegroundColor Cyan
kubectl get pods -n $Namespace
Write-Host "`n✨ Deployment completed successfully!" -ForegroundColor Green

Write-Host @"
🔍 Next steps:
1. Check pod status: kubectl get pods -n $Namespace
2. View logs: kubectl logs -f -n $Namespace <pod-name>
3. Monitor metrics: kubectl port-forward -n $Namespace svc/grafana 3000:3000
"@ -ForegroundColor Cyan 