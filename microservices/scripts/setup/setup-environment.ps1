# Setup environment for Avalanche Parallel Processing
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('docker-desktop', 'kind', 'minikube')]
    [string]$Provider,
    
    [switch]$Force = $false
)

Write-Host "⚙️ Setting up environment for Avalanche Parallel Processing..." -ForegroundColor Green

# Function to install Chocolatey
function Install-Chocolatey {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

# Function to install Docker Desktop
function Install-DockerDesktop {
    if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Docker Desktop..." -ForegroundColor Yellow
        choco install docker-desktop -y
    }
}

# Function to install Go
function Install-Go {
    if (!(Get-Command go -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Go..." -ForegroundColor Yellow
        choco install golang -y
    }
}

# Function to install Kubernetes tools
function Install-KubernetesTools {
    if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Host "Installing kubectl..." -ForegroundColor Yellow
        choco install kubernetes-cli -y
    }
    
    if ($Provider -eq "kind") {
        if (!(Get-Command kind -ErrorAction SilentlyContinue)) {
            Write-Host "Installing kind..." -ForegroundColor Yellow
            choco install kind -y
        }
    }
    elseif ($Provider -eq "minikube") {
        if (!(Get-Command minikube -ErrorAction SilentlyContinue)) {
            Write-Host "Installing minikube..." -ForegroundColor Yellow
            choco install minikube -y
        }
    }
}

# Function to setup Kubernetes
function Setup-Kubernetes {
    Write-Host "Setting up Kubernetes with $Provider..." -ForegroundColor Yellow
    
    switch ($Provider) {
        'docker-desktop' {
            Write-Host "Please enable Kubernetes in Docker Desktop settings manually." -ForegroundColor Cyan
            Read-Host "Press Enter after enabling Kubernetes in Docker Desktop"
            
            # Verify Kubernetes
            kubectl version
            if ($LASTEXITCODE -ne 0) {
                Write-Host "❌ Kubernetes setup failed." -ForegroundColor Red
                exit 1
            }
        }
        'kind' {
            Write-Host "Creating kind cluster..." -ForegroundColor Yellow
            kind create cluster --name avalanche-parallel
        }
        'minikube' {
            Write-Host "Starting minikube..." -ForegroundColor Yellow
            minikube start
        }
    }
}

# Function to create directories
function Create-Directories {
    Write-Host "Creating necessary directories..." -ForegroundColor Yellow
    
    $directories = @(
        "logs",
        "volumes",
        "volumes/redis",
        "volumes/postgres",
        "volumes/prometheus",
        "volumes/grafana"
    )
    
    foreach ($dir in $directories) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

# Function to setup configuration
function Setup-Configuration {
    Write-Host "Setting up configuration..." -ForegroundColor Yellow
    
    # Copy example files if they exist
    if (Test-Path .env.example) {
        Copy-Item -Path .env.example -Destination .env -Force
    }
    
    if (Test-Path config/worker-config.example.yaml) {
        Copy-Item -Path config/worker-config.example.yaml -Destination config/worker-config.yaml -Force
    }
}

try {
    # Install prerequisites
    Install-Chocolatey
    Install-DockerDesktop
    Install-Go
    Install-KubernetesTools
    
    # Setup Kubernetes
    Setup-Kubernetes
    
    # Create directories
    Create-Directories
    
    # Setup configuration
    Setup-Configuration
    
    Write-Host "`n✅ Environment setup completed!" -ForegroundColor Green
    Write-Host @"
🔍 Next steps:
1. Edit .env file with your configuration
2. Start services with: .\scripts\deployment\deploy-docker.ps1 -Build
3. Monitor with: http://localhost:3000 (Grafana)
"@ -ForegroundColor Cyan

} catch {
    Write-Host "❌ Error during setup: $_" -ForegroundColor Red
    exit 1
} 