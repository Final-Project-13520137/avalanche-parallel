# Script for scaling worker nodes in Avalanche Parallel Processing
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [int]$Workers,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("docker", "kubernetes")]
    [string]$Environment = "docker",

    [Parameter(Mandatory = $false)]
    [string]$Namespace = "avalanche-parallel",

    [Parameter(Mandatory = $false)]
    [string]$ComposeFile = "docker-compose.worker-pools.yml"
)

function Scale-DockerWorkers {
    param (
        [int]$Workers,
        [string]$ComposeFile
    )
    
    Write-Host "Scaling Docker workers to $Workers instances..."
    
    if (-not (Test-Path $ComposeFile)) {
        Write-Error "Docker compose file not found: $ComposeFile"
        exit 1
    }

    try {
        # Scale worker service
        docker-compose -f $ComposeFile up -d --scale worker=$Workers
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully scaled workers to $Workers instances" -ForegroundColor Green
        } else {
            Write-Error "Failed to scale workers"
            exit 1
        }
    }
    catch {
        Write-Error "Error scaling workers: $_"
        exit 1
    }
}

function Scale-KubernetesWorkers {
    param (
        [int]$Workers,
        [string]$Namespace
    )
    
    Write-Host "Scaling Kubernetes workers to $Workers instances..."
    
    try {
        # Check if kubectl is available
        if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
            Write-Error "kubectl not found. Please install kubectl and configure your Kubernetes cluster."
            exit 1
        }

        # Check if namespace exists
        $namespaceExists = kubectl get namespace $Namespace 2>$null
        if (-not $?) {
            Write-Error "Namespace '$Namespace' not found"
            exit 1
        }

        # Scale deployment
        kubectl scale deployment avalanche-worker -n $Namespace --replicas=$Workers
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully scaled workers to $Workers instances" -ForegroundColor Green
            
            # Wait for scaling to complete
            Write-Host "Waiting for scaling to complete..."
            kubectl rollout status deployment/avalanche-worker -n $Namespace
            
            # Show current pods
            Write-Host "`nCurrent worker pods:"
            kubectl get pods -n $Namespace -l app=avalanche-worker
        } else {
            Write-Error "Failed to scale workers"
            exit 1
        }
    }
    catch {
        Write-Error "Error scaling workers: $_"
        exit 1
    }
}

# Main execution
try {
    if ($Environment -eq "docker") {
        Scale-DockerWorkers -Workers $Workers -ComposeFile $ComposeFile
    } else {
        Scale-KubernetesWorkers -Workers $Workers -Namespace $Namespace
    }
}
catch {
    Write-Error "Error in main execution: $_"
    exit 1
} 