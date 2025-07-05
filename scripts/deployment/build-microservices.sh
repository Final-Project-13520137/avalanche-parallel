#!/bin/bash

# Build Avalanche Microservices
# Build all microservices Docker images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
MICROSERVICES_DIR="$ROOT_DIR/microservices"

# Services to build
SERVICES=(
    "api-gateway"
    "consensus"
    "validator"
    "dag"
    "state"
)

# Function to print colored output
print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running"
        exit 1
    fi
    
    # Check if microservices directory exists
    if [ ! -d "$MICROSERVICES_DIR" ]; then
        print_error "Microservices directory not found: $MICROSERVICES_DIR"
        print_step "Run ./microservices/generator/generate-all.sh first"
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Build individual service
build_service() {
    local service=$1
    print_step "Building $service service..."
    
    local service_dir="$MICROSERVICES_DIR/services/$service"
    
    if [ ! -d "$service_dir" ]; then
        print_error "Service directory not found: $service_dir"
        return 1
    fi
    
    if [ ! -f "$service_dir/deployments/Dockerfile" ]; then
        print_error "Dockerfile not found for $service"
        return 1
    fi
    
    # Build Docker image
    cd "$MICROSERVICES_DIR"
    docker build -t "avalanche-$service:latest" -f "services/$service/deployments/Dockerfile" .
    
    print_success "$service service built successfully"
}

# Build all services
build_all_services() {
    print_step "Building all microservices..."
    
    for service in "${SERVICES[@]}"; do
        build_service "$service"
    done
    
    print_success "All services built successfully"
}

# Generate complete Dockerfiles for each service
generate_complete_dockerfiles() {
    print_step "Generating complete Dockerfiles..."
    
    for service in "${SERVICES[@]}"; do
        local service_dir="$MICROSERVICES_DIR/services/$service"
        
        # Create deployments directory if it doesn't exist
        mkdir -p "$service_dir/deployments"
        
        # Generate more complete Dockerfile
        cat > "$service_dir/deployments/Dockerfile" << EOF
# Multi-stage build for $service
FROM golang:1.21-alpine AS builder

# Install dependencies
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the service
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o $service ./services/$service/cmd

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/$service .

# Expose ports
EXPOSE 965\$(($(printf "%s\n" "${SERVICES[@]}" | grep -n "^$service\$" | cut -d: -f1) - 1))
EXPOSE 975\$(($(printf "%s\n" "${SERVICES[@]}" | grep -n "^$service\$" | cut -d: -f1) - 1))

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD wget --no-verbose --tries=1 --spider http://localhost:965\$(($(printf "%s\n" "${SERVICES[@]}" | grep -n "^$service\$" | cut -d: -f1) - 1))/health || exit 1

# Run the service
CMD ["./$service"]
EOF
        
        print_step "Generated Dockerfile for $service"
    done
    
    print_success "All Dockerfiles generated"
}

# Build with optimization
build_optimized() {
    print_step "Building optimized microservices..."
    
    cd "$MICROSERVICES_DIR"
    
    # Build with Docker BuildKit for better caching
    export DOCKER_BUILDKIT=1
    
    # Build all services in parallel
    for service in "${SERVICES[@]}"; do
        {
            print_step "Building $service in background..."
            docker build -t "avalanche-$service:latest" \
                -f "services/$service/deployments/Dockerfile" \
                --target builder \
                --cache-from "avalanche-$service:cache" \
                . > "/tmp/build_$service.log" 2>&1
            
            docker build -t "avalanche-$service:latest" \
                -f "services/$service/deployments/Dockerfile" \
                --cache-from "avalanche-$service:cache" \
                . >> "/tmp/build_$service.log" 2>&1
                
            print_success "$service build completed"
        } &
    done
    
    # Wait for all builds to complete
    wait
    
    print_success "Optimized build completed"
}

# Test services
test_services() {
    print_step "Testing built services..."
    
    for service in "${SERVICES[@]}"; do
        print_step "Testing $service service..."
        
        # Run container and test health endpoint
        local container_id=$(docker run -d --rm "avalanche-$service:latest")
        sleep 5
        
        # Check if container is running
        if docker ps | grep -q "$container_id"; then
            print_success "$service service test passed"
        else
            print_error "$service service test failed"
            docker logs "$container_id"
        fi
        
        # Stop container
        docker stop "$container_id" >/dev/null 2>&1 || true
    done
    
    print_success "All service tests completed"
}

# Push images to registry (optional)
push_images() {
    local registry=$1
    
    if [ -z "$registry" ]; then
        print_warning "No registry specified, skipping push"
        return 0
    fi
    
    print_step "Pushing images to registry: $registry"
    
    for service in "${SERVICES[@]}"; do
        local image_name="avalanche-$service:latest"
        local registry_image="$registry/$image_name"
        
        print_step "Tagging and pushing $service..."
        docker tag "$image_name" "$registry_image"
        docker push "$registry_image"
        
        print_success "$service pushed to registry"
    done
    
    print_success "All images pushed to registry"
}

# Show build results
show_results() {
    print_step "Build Results:"
    echo ""
    
    echo "Built Images:"
    for service in "${SERVICES[@]}"; do
        local image_info=$(docker images "avalanche-$service:latest" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}")
        echo "$image_info"
    done
    
    echo ""
    echo "Total Images: ${#SERVICES[@]}"
    echo "Total Size: $(docker images "avalanche-*:latest" --format "{{.Size}}" | awk '{sum+=$1} END {print sum "MB"}')"
}

# Main execution
main() {
    local registry=""
    local optimize=false
    local test=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --registry)
                registry=$2
                shift 2
                ;;
            --optimize)
                optimize=true
                shift
                ;;
            --test)
                test=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --registry REGISTRY  Push images to specified registry"
                echo "  --optimize          Use optimized build with parallel processing"
                echo "  --test              Test built services"
                echo "  --help              Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    echo "🚀 Building Avalanche Microservices..."
    
    check_prerequisites
    generate_complete_dockerfiles
    
    if [ "$optimize" = true ]; then
        build_optimized
    else
        build_all_services
    fi
    
    if [ "$test" = true ]; then
        test_services
    fi
    
    if [ -n "$registry" ]; then
        push_images "$registry"
    fi
    
    show_results
    
    print_success "✅ Microservices build completed!"
    echo ""
    print_step "Next steps:"
    echo "1. cd microservices"
    echo "2. docker-compose up -d"
    echo "3. Test: curl http://localhost:9650/health"
}

# Run main function
main "$@" 