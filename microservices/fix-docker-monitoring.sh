#!/bin/bash

# Script untuk memperbaiki masalah Docker credentials dan menjalankan monitoring stack
set -e

echo "🔧 Memperbaiki masalah Docker monitoring stack..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to fix Docker credentials
fix_docker_credentials() {
    print_step "Memperbaiki Docker credentials..."
    
    # Check if docker login is needed
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker tidak berjalan atau tidak dapat diakses"
        return 1
    fi
    
    # Clear any problematic credential store
    if [ -f ~/.docker/config.json ]; then
        print_step "Backing up Docker config..."
        cp ~/.docker/config.json ~/.docker/config.json.backup
        
        # Remove credential store entries that might be causing issues
        print_step "Membersihkan konfigurasi credential store..."
        jq 'del(.credsStore) | del(.credHelpers)' ~/.docker/config.json > ~/.docker/config.json.tmp
        mv ~/.docker/config.json.tmp ~/.docker/config.json
    fi
    
    print_success "Docker credentials diperbaiki"
}

# Function to create worker network if not exists
create_worker_network() {
    print_step "Membuat network worker jika belum ada..."
    
    if ! docker network ls | grep -q "avalanche-worker-network"; then
        docker network create avalanche-worker-network
        print_success "Network avalanche-worker-network dibuat"
    else
        print_success "Network avalanche-worker-network sudah ada"
    fi
}

# Function to pull images without credential store
pull_images_manually() {
    print_step "Menarik Docker images secara manual..."
    
    # List of images to pull
    images=(
        "prom/prometheus:v2.40.0"
        "grafana/grafana:9.2.0"
        "prom/alertmanager:v0.25.0"
        "prom/node-exporter:v1.4.0"
        "gcr.io/cadvisor/cadvisor:v0.46.0"
        "oliver006/redis_exporter:v1.45.0"
        "redis:7-alpine"
        "prometheuscommunity/postgres-exporter:v0.11.1"
        "postgres:15-alpine"
        "grafana/loki:2.9.0"
        "grafana/promtail:2.9.0"
        "jaegertracing/all-in-one:1.38"
        "otel/opentelemetry-collector-contrib:0.68.0"
        "nginx:1.24-alpine"
    )
    
    for image in "${images[@]}"; do
        print_step "Pulling $image..."
        if docker pull "$image"; then
            print_success "Berhasil pull $image"
        else
            print_warning "Gagal pull $image, akan dicoba saat startup"
        fi
    done
}

# Function to create missing directories
create_monitoring_dirs() {
    print_step "Membuat direktori monitoring yang diperlukan..."
    
    directories=(
        "monitoring/prometheus"
        "monitoring/grafana/provisioning/datasources"
        "monitoring/grafana/provisioning/dashboards"
        "monitoring/grafana/dashboards"
        "monitoring/alertmanager"
        "monitoring/loki"
        "monitoring/promtail"
        "monitoring/otel"
        "monitoring/nginx"
        "sql"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_success "Direktori $dir dibuat"
        fi
    done
}

# Function to create minimal SQL init file if not exists
create_sql_init() {
    if [ ! -f "sql/init.sql" ]; then
        print_step "Membuat file init.sql..."
        cat > sql/init.sql << 'EOF'
-- Avalanche Parallel Database Initialization
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create tables for metrics storage
CREATE TABLE IF NOT EXISTS metrics_history (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    metric_name VARCHAR(255),
    metric_value DECIMAL,
    labels JSONB
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics_history(timestamp);
CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics_history(metric_name);

-- Create user for metrics
CREATE USER IF NOT EXISTS metrics_user WITH PASSWORD 'metrics_pass';
GRANT SELECT, INSERT ON metrics_history TO metrics_user;
GRANT USAGE ON SEQUENCE metrics_history_id_seq TO metrics_user;
EOF
        print_success "File sql/init.sql dibuat"
    fi
}

# Function to create missing config files
create_missing_configs() {
    print_step "Membuat file konfigurasi yang hilang..."
    
    # Create nginx config if missing
    if [ ! -f "monitoring/nginx/nginx.conf" ]; then
        cat > monitoring/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream grafana {
        server grafana:3000;
    }
    
    upstream prometheus {
        server prometheus:9090;
    }
    
    upstream alertmanager {
        server alertmanager:9093;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        location /grafana/ {
            proxy_pass http://grafana/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /prometheus/ {
            proxy_pass http://prometheus/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /alertmanager/ {
            proxy_pass http://alertmanager/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location / {
            return 302 /grafana/;
        }
    }
}
EOF
        print_success "File nginx.conf dibuat"
    fi
}

# Function to start monitoring stack
start_monitoring() {
    print_step "Memulai monitoring stack..."
    
    # Remove any existing containers first
    docker-compose -f docker-compose.monitoring.yml down --remove-orphans 2>/dev/null || true
    
    # Start the stack
    if docker-compose -f docker-compose.monitoring.yml up -d; then
        print_success "Monitoring stack berhasil dimulai"
        return 0
    else
        print_error "Gagal memulai monitoring stack"
        return 1
    fi
}

# Function to check service health
check_services() {
    print_step "Memeriksa status layanan..."
    
    # Wait a bit for services to start
    sleep 10
    
    services=("prometheus" "grafana" "alertmanager")
    ports=(9090 3000 9093)
    
    for i in "${!services[@]}"; do
        service="${services[$i]}"
        port="${ports[$i]}"
        
        if curl -s "http://localhost:$port" > /dev/null; then
            print_success "$service (port $port) - OK"
        else
            print_warning "$service (port $port) - Belum siap"
        fi
    done
}

# Main execution
main() {
    echo "🎯 Avalanche Parallel Monitoring Fix & Setup"
    echo "============================================"
    
    # Check if we're in the right directory
    if [ ! -f "docker-compose.monitoring.yml" ]; then
        print_error "File docker-compose.monitoring.yml tidak ditemukan!"
        print_error "Pastikan Anda berada di direktori microservices/"
        exit 1
    fi
    
    fix_docker_credentials
    create_worker_network
    create_monitoring_dirs
    create_sql_init
    create_missing_configs
    pull_images_manually
    
    if start_monitoring; then
        check_services
        
        echo ""
        echo "📊 Endpoint monitoring:"
        echo "- Grafana: http://localhost:3000 (admin/admin)"
        echo "- Prometheus: http://localhost:9090"
        echo "- AlertManager: http://localhost:9093"
        echo ""
        print_success "Setup selesai!"
    else
        print_error "Setup gagal. Cek log dengan: docker-compose -f docker-compose.monitoring.yml logs"
        exit 1
    fi
}

# Run main function
main "$@" 