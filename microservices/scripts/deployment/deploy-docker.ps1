# Deploy Docker services for Avalanche Parallel Processing
param(
    [switch]$Build = $false,
    [int]$Workers = 3,
    [string]$ComposeFile = "docker-compose.worker-pools.yml"
)

Write-Host "🚀 Deploying Avalanche Parallel Processing with Docker..." -ForegroundColor Green

# Build images if requested
if ($Build) {
    Write-Host "🔨 Building Docker images..." -ForegroundColor Yellow
    docker-compose -f $ComposeFile build
}

# Start services
Write-Host "📦 Starting services with $Workers workers..." -ForegroundColor Yellow
docker-compose -f $ComposeFile up -d --scale validator-worker=$Workers

Write-Host "✅ Deployment completed!" -ForegroundColor Green
Write-Host "ℹ️ Use 'docker-compose -f $ComposeFile logs -f' to view logs" -ForegroundColor Cyan 