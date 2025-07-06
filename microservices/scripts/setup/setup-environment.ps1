# Setup environment for Avalanche Parallel Processing
param(
    [string]$Provider = "docker-desktop"
)

Write-Host "⚙️ Setting up environment for Avalanche Parallel Processing..." -ForegroundColor Green

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check Docker
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker not found. Please install Docker Desktop." -ForegroundColor Red
    exit 1
}

# Check Docker Compose
if (!(Get-Command docker-compose -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker Compose not found. Please install Docker Compose." -ForegroundColor Red
    exit 1
}

# Check Go
if (!(Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Go not found. Please install Go." -ForegroundColor Red
    exit 1
}

# Setup Kubernetes if needed
if ($Provider -eq "docker-desktop") {
    Write-Host "Setting up Docker Desktop Kubernetes..." -ForegroundColor Yellow
    
    # Enable Kubernetes in Docker Desktop
    Write-Host "Please enable Kubernetes in Docker Desktop settings manually." -ForegroundColor Cyan
    
    # Wait for confirmation
    Read-Host "Press Enter after enabling Kubernetes in Docker Desktop"
    
    # Verify Kubernetes
    kubectl version
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Kubernetes setup failed." -ForegroundColor Red
        exit 1
    }
}
elseif ($Provider -eq "kind") {
    Write-Host "Setting up kind cluster..." -ForegroundColor Yellow
    
    # Install kind if not present
    if (!(Get-Command kind -ErrorAction SilentlyContinue)) {
        Write-Host "Installing kind..." -ForegroundColor Cyan
        choco install kind -y
    }
    
    # Create kind cluster
    kind create cluster --name avalanche-parallel
}
elseif ($Provider -eq "minikube") {
    Write-Host "Setting up minikube..." -ForegroundColor Yellow
    
    # Install minikube if not present
    if (!(Get-Command minikube -ErrorAction SilentlyContinue)) {
        Write-Host "Installing minikube..." -ForegroundColor Cyan
        choco install minikube -y
    }
    
    # Start minikube
    minikube start
}

# Create necessary directories
Write-Host "Creating necessary directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path logs
New-Item -ItemType Directory -Force -Path volumes

# Copy configuration files
Write-Host "Setting up configuration..." -ForegroundColor Yellow
Copy-Item -Path .env.example -Destination .env -Force

Write-Host "✅ Environment setup completed!" -ForegroundColor Green
Write-Host @"
🔍 Next steps:
1. Edit .env file with your configuration
2. Run deployment script:
   .\scripts\deployment\deploy-docker.ps1 -Build
"@ -ForegroundColor Cyan 