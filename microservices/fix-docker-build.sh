#!/bin/bash

# Fix Docker Build Issues for Avalanche Microservices
# This script addresses Docker credential and image pulling issues

echo "🔧 Fixing Docker Build Issues for Avalanche Microservices..."

# Function to check if Docker is running
check_docker_running() {
    if ! docker version >/dev/null 2>&1; then
        echo "❌ Docker is not running. Please start Docker first."
        exit 1
    fi
    echo "✅ Docker is running"
}

# Function to clear Docker credentials
clear_docker_credentials() {
    echo "🧹 Clearing Docker credentials..."
    
    # Clear Docker credentials
    if docker logout >/dev/null 2>&1; then
        echo "✅ Docker logout completed"
    else
        echo "⚠️  Docker logout failed (this is normal if not logged in)"
    fi
    
    # Clear Docker config
    if [ -d "$HOME/.docker" ]; then
        echo "🗑️  Clearing Docker config directory"
        rm -rf "$HOME/.docker/config.json" 2>/dev/null || true
    fi
}

# Function to pull base images manually
pull_base_images() {
    echo "📥 Pulling base images manually..."
    
    images=(
        "golang:1.22-alpine"
        "golang:1.21-alpine"
        "alpine:latest"
        "alpine:3.18"
        "redis:7-alpine"
        "postgres:15-alpine"
        "haproxy:2.4"
        "prom/prometheus:v2.45.0"
        "grafana/grafana:10.0.3"
        "prom/alertmanager:v0.25.0"
    )
    
    for image in "${images[@]}"; do
        echo "📥 Pulling $image..."
        if docker pull "$image" >/dev/null 2>&1; then
            echo "✅ Successfully pulled $image"
        else
            echo "❌ Failed to pull $image"
        fi
    done
}

# Function to create alternative Dockerfiles with different base images
create_alternative_dockerfiles() {
    echo "🔧 Creating alternative Dockerfiles with different base images..."
    
    # Create alternative Dockerfile for consensus-worker
    cat > workers/consensus-worker/Dockerfile.alternative << 'EOF'
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
EOF

    # Create alternative Dockerfile for api-gateway
    cat > api-gateway/Dockerfile.alternative << 'EOF'
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
EOF

    # Create alternative Dockerfile for validator-worker
    cat > workers/validator-worker/Dockerfile.alternative << 'EOF'
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
RUN CGO_ENABLED=0 GOOS=linux go build -o validator-worker cmd/main.go

# Create final image
FROM alpine:3.18

# Install wget for healthcheck
RUN apk add --no-cache wget

# Copy binary from builder
COPY --from=builder /app/validator-worker .

# Expose metrics port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8081/health || exit 1

# Run
CMD ["./validator-worker"]
EOF

    # Create alternative Dockerfile for dag-state-worker
    cat > workers/dag-state-worker/Dockerfile.alternative << 'EOF'
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
RUN CGO_ENABLED=0 GOOS=linux go build -o dag-state-worker cmd/main.go

# Create final image
FROM alpine:3.18

# Install wget for healthcheck
RUN apk add --no-cache wget

# Copy binary from builder
COPY --from=builder /app/dag-state-worker .

# Expose metrics port
EXPOSE 8082

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8082/health || exit 1

# Run
CMD ["./dag-state-worker"]
EOF

    echo "✅ Alternative Dockerfiles created"
}

# Function to create a simplified docker-compose for testing
create_simplified_compose() {
    echo "🔧 Creating simplified docker-compose for testing..."
    
    cat > docker-compose.test.yml << 'EOF'
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
EOF

    echo "✅ Simplified docker-compose.test.yml created"
}

# Function to provide troubleshooting steps
show_troubleshooting_steps() {
    echo ""
    echo "🔍 Troubleshooting Steps:"
    echo "1. Check Docker is running: docker version"
    echo "2. Try: docker system prune -a"
    echo "3. Try: docker builder prune"
    echo "4. Check your internet connection"
    echo "5. Try using VPN if behind corporate firewall"
    echo "6. Try: docker pull golang:1.22-alpine manually"
    echo "7. Use alternative Dockerfiles: docker-compose -f docker-compose.test.yml up"
    echo "8. Check Docker Hub status: https://status.docker.com/"
    echo "9. Try: docker pull golang:1.21-alpine (alternative version)"
    echo "10. Check Docker daemon logs: journalctl -u docker"
}

# Function to clean Docker system
clean_docker_system() {
    echo "🧹 Cleaning Docker system..."
    
    echo "Clearing unused images..."
    docker image prune -f >/dev/null 2>&1 || true
    
    echo "Clearing unused containers..."
    docker container prune -f >/dev/null 2>&1 || true
    
    echo "Clearing unused networks..."
    docker network prune -f >/dev/null 2>&1 || true
    
    echo "Clearing build cache..."
    docker builder prune -f >/dev/null 2>&1 || true
    
    echo "✅ Docker system cleaned"
}

# Main execution
check_docker_running

# Clean Docker system
clean_docker_system

# Clear credentials
clear_docker_credentials

# Pull base images
pull_base_images

# Create alternative files
create_alternative_dockerfiles
create_simplified_compose

# Show troubleshooting steps
show_troubleshooting_steps

echo ""
echo "🎯 Next Steps:"
echo "1. Try building with: docker-compose -f docker-compose.worker-pools.yml build"
echo "2. If that fails, try: docker-compose -f docker-compose.test.yml up --build"
echo "3. If still failing, check the troubleshooting steps above"
echo "4. Try using alternative Dockerfiles by renaming them:"
echo "   mv workers/consensus-worker/Dockerfile.alternative workers/consensus-worker/Dockerfile"

echo ""
echo "✅ Fix script completed!" 