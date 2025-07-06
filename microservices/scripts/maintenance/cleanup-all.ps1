# Cleanup script for Avalanche Parallel Processing

param(
    [switch]$Force
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Get-Item $ScriptDir).Parent.Parent.FullName

# Function to safely execute docker commands
function Invoke-SafeDockerCommand {
    param(
        [string]$Command,
        [string]$Message
    )
    Write-Host $Message -ForegroundColor Cyan
    try {
        Invoke-Expression $Command
        return $true
    }
    catch {
        Write-Warning "Command failed: $Message`nError: $_"
        return $false
    }
}

# Function to check if Docker is running
function Test-DockerRunning {
    try {
        docker info > $null 2>&1
        return $true
    }
    catch {
        Write-Host "Error: Docker is not running" -ForegroundColor Red
        return $false
    }
}

# Function to check if kubectl is available
function Test-KubectlAvailable {
    try {
        kubectl version --client > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}

# Function to cleanup Kubernetes resources
function Remove-KubernetesResources {
    Write-Host "Checking for Kubernetes resources..." -ForegroundColor Cyan
    if (Test-KubectlAvailable) {
        Write-Host "Found kubectl, cleaning up Kubernetes resources..." -ForegroundColor Cyan
        
        # Check if avalanche namespace exists
        try {
            $namespace = kubectl get namespace avalanche 2>$null
            if ($?) {
                Write-Host "Deleting all resources in avalanche namespace..." -ForegroundColor Cyan
                Invoke-SafeDockerCommand `
                    -Command "kubectl delete namespace avalanche --grace-period=0 --force" `
                    -Message "Deleting avalanche namespace"
                
                # Wait for namespace deletion
                Write-Host "Waiting for namespace deletion..." -ForegroundColor Cyan
                while ($true) {
                    try {
                        kubectl get namespace avalanche > $null 2>&1
                        Write-Host "." -NoNewline
                        Start-Sleep -Seconds 1
                    }
                    catch {
                        break
                    }
                }
                Write-Host
            }
            else {
                Write-Host "No avalanche namespace found in Kubernetes" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Failed to check Kubernetes namespace: $_"
        }
    }
    else {
        Write-Host "kubectl not found, skipping Kubernetes cleanup" -ForegroundColor Yellow
    }
}

Write-Host "🧹 Starting cleanup process..." -ForegroundColor Yellow

# Check if Docker is running
if (-not (Test-DockerRunning)) {
    exit 1
}

# Stop all containers
Write-Host "Stopping all containers..." -ForegroundColor Cyan
$DockerComposePath = Join-Path $ProjectRoot "docker-compose.worker-pools.yml"
if (Test-Path $DockerComposePath) {
    Invoke-SafeDockerCommand `
        -Command "docker-compose -f '$DockerComposePath' down" `
        -Message "Stopping docker-compose services..."
}
else {
    Write-Warning "docker-compose.worker-pools.yml not found"
}

if ($Force) {
    Write-Host "Performing force cleanup..." -ForegroundColor Red

    # First, cleanup Kubernetes resources
    Remove-KubernetesResources
    
    # Remove all project-related containers
    Write-Host "Checking for project containers..." -ForegroundColor Cyan
    $Containers = docker ps -a --filter "name=avalanche" --filter "name=microservices" --filter "name=k8s" -q
    if ($Containers) {
        Write-Host "Found containers to remove:" -ForegroundColor Cyan
        docker ps -a --filter "name=avalanche" --filter "name=microservices" --filter "name=k8s" --format "table {{.ID}}`t{{.Names}}`t{{.Status}}"
        
        # Stop containers first
        Write-Host "Stopping containers..." -ForegroundColor Cyan
        $Containers | ForEach-Object {
            Invoke-SafeDockerCommand `
                -Command "docker stop $_" `
                -Message "Stopping container $_"
        }
        
        # Then remove them
        Write-Host "Removing containers..." -ForegroundColor Cyan
        $Containers | ForEach-Object {
            Invoke-SafeDockerCommand `
                -Command "docker rm -f $_" `
                -Message "Removing container $_"
        }
    }
    else {
        Write-Host "No project containers found" -ForegroundColor Green
    }

    # Remove project images
    Write-Host "Checking for project images..." -ForegroundColor Cyan
    $Images = docker images --filter "reference=avalanche*" --filter "reference=microservices*" --filter "reference=k8s.gcr.io/*" -q
    if ($Images) {
        Write-Host "Removing images:" -ForegroundColor Cyan
        docker images --filter "reference=avalanche*" --filter "reference=microservices*" --filter "reference=k8s.gcr.io/*" --format "table {{.ID}}`t{{.Repository}}`t{{.Tag}}"
        $Images | ForEach-Object {
            Invoke-SafeDockerCommand `
                -Command "docker rmi -f $_" `
                -Message "Removing image $_"
        }
    }
    else {
        Write-Host "No project images found" -ForegroundColor Green
    }

    # Remove volumes
    Write-Host "Checking for project volumes..." -ForegroundColor Cyan
    $Volumes = docker volume ls --filter "name=microservices" --filter "name=k8s" -q
    if ($Volumes) {
        Write-Host "Removing volumes:" -ForegroundColor Cyan
        docker volume ls --filter "name=microservices" --filter "name=k8s" --format "table {{.Name}}`t{{.Driver}}"
        $Volumes | ForEach-Object {
            Invoke-SafeDockerCommand `
                -Command "docker volume rm -f $_" `
                -Message "Removing volume $_"
        }
    }
    else {
        Write-Host "No project volumes found" -ForegroundColor Green
    }

    # Remove networks
    Write-Host "Checking for project networks..." -ForegroundColor Cyan
    $Networks = docker network ls --filter "name=avalanche" --filter "name=microservices" --filter "name=k8s" -q
    if ($Networks) {
        Write-Host "Removing networks:" -ForegroundColor Cyan
        docker network ls --filter "name=avalanche" --filter "name=microservices" --filter "name=k8s" --format "table {{.ID}}`t{{.Name}}`t{{.Driver}}"
        $Networks | ForEach-Object {
            Invoke-SafeDockerCommand `
                -Command "docker network rm $_" `
                -Message "Removing network $_"
        }
    }
    else {
        Write-Host "No project networks found" -ForegroundColor Green
    }

    # Prune system
    Write-Host "Pruning unused Docker resources..." -ForegroundColor Cyan
    Invoke-SafeDockerCommand `
        -Command "docker system prune -f" `
        -Message "Pruning system..."
}

Write-Host "✅ Cleanup completed!" -ForegroundColor Green

# Final status check
Write-Host "`nFinal status:" -ForegroundColor Cyan
Write-Host "Remaining containers:" -ForegroundColor Cyan
$RemainingContainers = docker ps -a --filter "name=avalanche" --filter "name=microservices" --filter "name=k8s" --format "table {{.ID}}`t{{.Names}}`t{{.Status}}" 2>$null
if ($RemainingContainers) { $RemainingContainers } else { "None" }

Write-Host "`nRemaining images:" -ForegroundColor Cyan
$RemainingImages = docker images --filter "reference=avalanche*" --filter "reference=microservices*" --filter "reference=k8s.gcr.io/*" --format "table {{.ID}}`t{{.Repository}}`t{{.Tag}}" 2>$null
if ($RemainingImages) { $RemainingImages } else { "None" } 