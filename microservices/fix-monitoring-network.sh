#!/bin/bash

# Script untuk memperbaiki konflik network monitoring
set -e

echo "🔧 Memperbaiki konflik network monitoring..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "docker-compose.monitoring.yml" ]; then
    print_error "File docker-compose.monitoring.yml tidak ditemukan!"
    print_error "Pastikan Anda berada di direktori microservices/"
    exit 1
fi

# 1. Stop and remove any existing monitoring containers
print_step "Menghentikan container monitoring yang ada..."
docker-compose -f docker-compose.monitoring.yml down --remove-orphans 2>/dev/null || true

# 2. Remove conflicting networks
print_step "Membersihkan network yang konflik..."

# List of potentially conflicting networks
networks_to_check=(
    "microservices_monitoring"
    "monitoring"
    "avalanche-monitoring"
)

for network in "${networks_to_check[@]}"; do
    if docker network ls --format "{{.Name}}" | grep -q "^${network}$"; then
        print_warning "Menghapus network: $network"
        docker network rm "$network" 2>/dev/null || true
    fi
done

# 3. Check existing subnet usage
print_step "Memeriksa penggunaan subnet yang ada..."
echo "Subnet yang sedang digunakan:"
docker network ls --format "{{.Name}}" | while read network; do
    if [ "$network" != "bridge" ] && [ "$network" != "host" ] && [ "$network" != "none" ]; then
        subnet=$(docker network inspect "$network" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "N/A")
        if [ "$subnet" != "N/A" ] && [ -n "$subnet" ]; then
            echo "  - $network: $subnet"
        fi
    fi
done

# 4. Create avalanche-worker-network if it doesn't exist
print_step "Memastikan network worker tersedia..."
if ! docker network ls --format "{{.Name}}" | grep -q "^avalanche-worker-network$"; then
    docker network create avalanche-worker-network --subnet=172.25.0.0/16
    print_success "Network avalanche-worker-network dibuat dengan subnet 172.25.0.0/16"
else
    print_success "Network avalanche-worker-network sudah ada"
fi

# 5. Prune unused networks to clean up
print_step "Membersihkan network yang tidak digunakan..."
docker network prune -f

# 6. Test network creation without starting services
print_step "Testing konfigurasi network monitoring..."
if docker network create test-monitoring --subnet=172.30.0.0/16 2>/dev/null; then
    docker network rm test-monitoring
    print_success "Subnet 172.30.0.0/16 tersedia untuk monitoring"
else
    print_warning "Subnet 172.30.0.0/16 mungkin konflik, menggunakan alternatif..."
    
    # Try alternative subnets
    alternative_subnets=(
        "172.31.0.0/16"
        "172.32.0.0/16"
        "10.30.0.0/16"
        "192.168.30.0/24"
    )
    
    for subnet in "${alternative_subnets[@]}"; do
        network_name="test-monitoring-$(echo $subnet | tr '/' '-' | tr '.' '-')"
        if docker network create "$network_name" --subnet="$subnet" 2>/dev/null; then
            docker network rm "$network_name"
            print_success "Menggunakan subnet alternatif: $subnet"
            
            # Update docker-compose.yml with the working subnet
            gateway=$(echo $subnet | sed 's/0\/[0-9]*$/1/')
            sed -i.bak "s|subnet: 172\.30\.0\.0/16|subnet: $subnet|g" docker-compose.monitoring.yml
            sed -i.bak "s|gateway: 172\.30\.0\.1|gateway: $gateway|g" docker-compose.monitoring.yml
            print_success "File docker-compose.monitoring.yml diupdate dengan subnet $subnet"
            break
        fi
    done
fi

# 7. Start monitoring stack
print_step "Memulai monitoring stack..."
if docker-compose -f docker-compose.monitoring.yml up -d; then
    print_success "Monitoring stack berhasil dimulai!"
    
    # Wait a bit and check status
    sleep 5
    echo ""
    print_step "Status container:"
    docker-compose -f docker-compose.monitoring.yml ps
    
    echo ""
    print_success "Setup selesai! Endpoints tersedia:"
    echo "  - Grafana: http://localhost:3000 (admin/admin)"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - AlertManager: http://localhost:9093"
    
else
    print_error "Gagal memulai monitoring stack"
    echo ""
    print_step "Log error:"
    docker-compose -f docker-compose.monitoring.yml logs --tail=20
    exit 1
fi 