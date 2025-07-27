#!/bin/bash

# Script sederhana untuk memperbaiki masalah Docker monitoring
set -e

echo "🔧 Memperbaiki monitoring stack Avalanche Parallel..."

# Warna untuk output
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

# Cek apakah kita di direktori yang benar
if [ ! -f "docker-compose.monitoring.yml" ]; then
    print_error "File docker-compose.monitoring.yml tidak ditemukan!"
    print_error "Pastikan Anda berada di direktori microservices/"
    exit 1
fi

# 1. Bersihkan Docker credentials yang bermasalah
print_step "Membersihkan Docker credentials..."
if [ -f ~/.docker/config.json ]; then
    # Backup file asli
    cp ~/.docker/config.json ~/.docker/config.json.backup
    
    # Buat config baru tanpa credential store
    cat > ~/.docker/config.json << 'EOF'
{
    "auths": {}
}
EOF
    print_success "Docker config dibersihkan"
else
    # Buat direktori dan config baru
    mkdir -p ~/.docker
    echo '{"auths": {}}' > ~/.docker/config.json
    print_success "Docker config baru dibuat"
fi

# 2. Buat network jika belum ada
print_step "Membuat network worker..."
if ! docker network ls | grep -q "avalanche-worker-network"; then
    docker network create avalanche-worker-network
    print_success "Network avalanche-worker-network dibuat"
else
    print_success "Network avalanche-worker-network sudah ada"
fi

# 3. Buat direktori yang diperlukan
print_step "Membuat direktori monitoring..."
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

# 4. Buat file init.sql jika belum ada
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
EOF
    print_success "File sql/init.sql dibuat"
fi

# 5. Buat nginx config jika belum ada
if [ ! -f "monitoring/nginx/nginx.conf" ]; then
    print_step "Membuat konfigurasi nginx..."
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

# 6. Bersihkan container lama
print_step "Membersihkan container lama..."
docker-compose -f docker-compose.monitoring.yml down --remove-orphans 2>/dev/null || true

# 7. Coba tarik image satu per satu untuk menghindari masalah credentials
print_step "Menarik Docker images..."
images=(
    "redis:7-alpine"
    "postgres:15-alpine"
    "nginx:1.24-alpine"
    "prom/prometheus:v2.40.0"
    "grafana/grafana:9.2.0"
    "prom/alertmanager:v0.25.0"
    "prom/node-exporter:v1.4.0"
)

for image in "${images[@]}"; do
    if docker pull "$image" 2>/dev/null; then
        print_success "Berhasil pull $image"
    else
        print_warning "Skip $image - akan dicoba saat startup"
    fi
done

# 8. Mulai monitoring stack
print_step "Memulai monitoring stack..."
if docker-compose -f docker-compose.monitoring.yml up -d; then
    print_success "Monitoring stack berhasil dimulai"
    
    # 9. Tunggu sebentar dan cek layanan
    print_step "Menunggu layanan siap..."
    sleep 15
    
    # Cek layanan utama
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        print_success "Grafana (port 3000) - Siap"
    else
        print_warning "Grafana masih loading..."
    fi
    
    if curl -s http://localhost:9090 > /dev/null 2>&1; then
        print_success "Prometheus (port 9090) - Siap"
    else
        print_warning "Prometheus masih loading..."
    fi
    
    echo ""
    echo "📊 Endpoint monitoring:"
    echo "- Grafana: http://localhost:3000 (admin/admin)"
    echo "- Prometheus: http://localhost:9090"
    echo "- AlertManager: http://localhost:9093"
    echo ""
    
    print_step "Cek status container:"
    docker-compose -f docker-compose.monitoring.yml ps
    
    print_success "Setup selesai! Jika ada layanan yang belum siap, tunggu beberapa menit."
    
else
    print_error "Gagal memulai monitoring stack"
    echo ""
    print_step "Log error:"
    docker-compose -f docker-compose.monitoring.yml logs --tail=20
    exit 1
fi 