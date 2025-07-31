# Fix Docker Build Issues for Avalanche Microservices
# This script addresses Docker credential and image pulling issues

Write-Host "🔧 Fixing Docker Build Issues for Avalanche Microservices..." -ForegroundColor Green

# Function to check if Docker is running
function Test-DockerRunning {
    try {
        docker version | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to clear Docker credentials
function Clear-DockerCredentials {
    Write-Host "🧹 Clearing Docker credentials..." -ForegroundColor Yellow
    
    # Clear Docker credentials on Windows
    try {
        docker logout
        Write-Host "✅ Docker logout completed" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Docker logout failed (this is normal if not logged in)" -ForegroundColor Yellow
    }
    
    # Clear credential manager entries
    try {
        cmdkey /list | findstr "docker" | ForEach-Object {
            $credName = ($_ -split '\s+')[1]
            cmdkey /delete:$credName
            Write-Host "🗑️  Cleared credential: $credName" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "⚠️  No Docker credentials found in credential manager" -ForegroundColor Yellow
    }
}

# Function to pull base images manually
function Pull-BaseImages {
    Write-Host "📥 Pulling base images manually..." -ForegroundColor Yellow
    
    $images = @(
        "golang:1.22-alpine",
        "alpine:latest",
        "redis:7-alpine",
        "postgres:15-alpine",
        "haproxy:2.4",
        "prom/prometheus:v2.45.0",
        "grafana/grafana:10.0.3",
        "prom/alertmanager:v0.25.0"
    )
    
    foreach ($image in $images) {
        Write-Host "📥 Pulling $image..." -ForegroundColor Cyan
        try {
            docker pull $image
            Write-Host "✅ Successfully pulled $image" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to pull $image" -ForegroundColor Red
            Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Function to create alternative Dockerfiles with different base images
function Create-AlternativeDockerfiles {
    Write-Host "🔧 Creating alternative Dockerfiles with different base images..." -ForegroundColor Yellow
    
    # Create alternative Dockerfile for consensus-worker
    $consensusAlt = @"
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && \
    go get -u github.com/go-redis/redis/v8@v8.11.5 && \
    go get -u github.com/prometheus/client_golang@v1.16.0 && \
    go get -u github.com/golang/protobuf/proto@v1.5.3 && \
    go get -u google.golang.org/protobuf@v1.30.0 && \
    go get -u golang.org/x/sys@v0.8.0 && \
    go mod tidy

# Copy source code
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o consensus-worker cmd/main.go

# Create final image
FROM alpine:3.18

# Copy binary from builder
COPY --from=builder /app/consensus-worker .

# Expose metrics port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run
CMD ["./consensus-worker"]
"@
    
    Set-Content -Path "workers/consensus-worker/Dockerfile.alternative" -Value $consensusAlt
    
    # Create alternative Dockerfile for api-gateway
    $apiGatewayAlt = @"
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o api-gateway cmd/main.go

# Create final image
FROM alpine:3.18

# Copy binary from builder
COPY --from=builder /build/api-gateway /app/api-gateway

# Set working directory
WORKDIR /app

# Expose ports
EXPOSE 9650 9750

# Run
CMD ["./api-gateway"]
"@
    
    Set-Content -Path "api-gateway/Dockerfile.alternative" -Value $apiGatewayAlt
    
    Write-Host "✅ Alternative Dockerfiles created" -ForegroundColor Green
}

# Function to create a simplified docker-compose for testing
function Create-SimplifiedCompose {
    Write-Host "🔧 Creating simplified docker-compose for testing..." -ForegroundColor Yellow
    
    $simplifiedCompose = @"
# Simplified Docker Compose for testing
version: '3.8'

services:
  # Test with just Redis and Postgres first
  redis:
    image: redis:7-alpine
    container_name: avalanche-redis-test
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    container_name: avalanche-postgres-test
    environment:
      POSTGRES_DB: avalanche
      POSTGRES_USER: avalanche
      POSTGRES_PASSWORD: avalanche123
    ports:
      - "5432:5432"
    restart: unless-stopped

  # Test one worker with alternative Dockerfile
  consensus-worker-test:
    build:
      context: ./workers/consensus-worker
      dockerfile: Dockerfile.alternative
    container_name: consensus-worker-test
    environment:
      - WORKER_TYPE=consensus
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
    restart: unless-stopped
"@
    
    Set-Content -Path "docker-compose.test.yml" -Value $simplifiedCompose
    Write-Host "✅ Simplified docker-compose.test.yml created" -ForegroundColor Green
}

# Function to provide troubleshooting steps
function Show-TroubleshootingSteps {
    Write-Host "`n🔍 Troubleshooting Steps:" -ForegroundColor Cyan
    Write-Host "1. Check Docker Desktop is running" -ForegroundColor White
    Write-Host "2. Try: docker system prune -a" -ForegroundColor White
    Write-Host "3. Try: docker builder prune" -ForegroundColor White
    Write-Host "4. Check your internet connection" -ForegroundColor White
    Write-Host "5. Try using VPN if behind corporate firewall" -ForegroundColor White
    Write-Host "6. Try: docker pull golang:1.22-alpine manually" -ForegroundColor White
    Write-Host "7. Use alternative Dockerfiles: docker-compose -f docker-compose.test.yml up" -ForegroundColor White
    Write-Host "8. Check Docker Hub status: https://status.docker.com/" -ForegroundColor White
}

# Main execution
if (-not (Test-DockerRunning)) {
    Write-Host "❌ Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Docker is running" -ForegroundColor Green

# Clear credentials
Clear-DockerCredentials

# Pull base images
Pull-BaseImages

# Create alternative files
Create-AlternativeDockerfiles
Create-SimplifiedCompose

# Show troubleshooting steps
Show-TroubleshootingSteps

Write-Host "`n🎯 Next Steps:" -ForegroundColor Green
Write-Host "1. Try building with: docker-compose -f docker-compose.worker-pools.yml build" -ForegroundColor White
Write-Host "2. If that fails, try: docker-compose -f docker-compose.test.yml up --build" -ForegroundColor White
Write-Host "3. If still failing, check the troubleshooting steps above" -ForegroundColor White

Write-Host "`n✅ Fix script completed!" -ForegroundColor Green 