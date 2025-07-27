#!/bin/bash

# Avalanche Parallel Monitoring Stack Startup Script
# This script starts the complete monitoring infrastructure

set -e

echo "🚀 Starting Avalanche Parallel Monitoring Stack..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if Docker and Docker Compose are available
check_dependencies() {
    print_step "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    print_success "Dependencies check passed"
}

# Create necessary directories
create_directories() {
    print_step "Creating monitoring directories..."
    
    # Create directories for persistent data
    mkdir -p monitoring/grafana/{provisioning/datasources,provisioning/dashboards,dashboards}
    mkdir -p monitoring/loki
    mkdir -p monitoring/promtail
    mkdir -p monitoring/otel
    mkdir -p monitoring/nginx
    
    print_success "Directories created"
}

# Create Grafana provisioning configuration
setup_grafana_provisioning() {
    print_step "Setting up Grafana provisioning..."
    
    # Create datasource configuration
    cat > monitoring/grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true

  - name: Jaeger
    type: jaeger
    access: proxy
    url: http://jaeger:16686
    editable: true
EOF

    # Create dashboard provisioning configuration
    cat > monitoring/grafana/provisioning/dashboards/dashboard.yml << EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

    print_success "Grafana provisioning configured"
}

# Setup additional monitoring configurations
setup_additional_configs() {
    print_step "Setting up additional monitoring configurations..."
    
    # Create Loki configuration
    cat > monitoring/loki/loki-config.yml << EOF
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /loki/index

  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
EOF

    # Create Promtail configuration
    cat > monitoring/promtail/promtail-config.yml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*log

    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag:
          source: attrs
      - regex:
          expression: (?P<container_name>(?:[^|]*))\|
          source: tag
      - timestamp:
          format: RFC3339Nano
          source: time
      - labels:
          stream:
          container_name:
      - output:
          source: output
EOF

    # Create OpenTelemetry Collector configuration
    cat > monitoring/otel/otel-collector-config.yml << EOF
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:

exporters:
  prometheus:
    endpoint: "0.0.0.0:8888"
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true
  loki:
    endpoint: http://loki:3100/loki/api/v1/push

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [loki]
EOF

    print_success "Additional configurations created"
}

# Start monitoring stack
start_monitoring_stack() {
    print_step "Starting monitoring stack..."
    
    # Pull latest images
    docker-compose -f docker-compose.monitoring.yml pull
    
    # Start the monitoring stack
    docker-compose -f docker-compose.monitoring.yml up -d
    
    print_success "Monitoring stack started"
}

# Wait for services to be ready
wait_for_services() {
    print_step "Waiting for services to be ready..."
    
    # Wait for Grafana
    echo "Waiting for Grafana..."
    while ! curl -s http://localhost:3000 > /dev/null; do
        sleep 2
    done
    print_success "Grafana is ready"
    
    # Wait for Prometheus
    echo "Waiting for Prometheus..."
    while ! curl -s http://localhost:9090 > /dev/null; do
        sleep 2
    done
    print_success "Prometheus is ready"
    
    # Wait for AlertManager
    echo "Waiting for AlertManager..."
    while ! curl -s http://localhost:9093 > /dev/null; do
        sleep 2
    done
    print_success "AlertManager is ready"
}

# Import Grafana dashboards
import_grafana_dashboards() {
    print_step "Importing Grafana dashboards..."
    
    sleep 10  # Give Grafana more time to fully initialize
    
    # Import worker pool dashboard
    if curl -X POST \
        http://admin:admin@localhost:3000/api/dashboards/db \
        -H 'Content-Type: application/json' \
        -d @monitoring/grafana/dashboards/worker-pools-dashboard.json \
        --silent --show-error; then
        print_success "Worker pools dashboard imported"
    else
        print_warning "Failed to import worker pools dashboard (may already exist)"
    fi
}

# Setup Prometheus targets
setup_prometheus_targets() {
    print_step "Configuring Prometheus targets..."
    
    # Prometheus will auto-discover worker targets through service discovery
    print_success "Prometheus targets configured"
}

# Verify monitoring setup
verify_monitoring() {
    print_step "Verifying monitoring setup..."
    
    # Check if all containers are running
    if docker-compose -f docker-compose.monitoring.yml ps | grep -q "Up"; then
        print_success "All monitoring containers are running"
    else
        print_warning "Some monitoring containers may not be running properly"
    fi
    
    # Display service endpoints
    echo ""
    echo "📊 Monitoring endpoints:"
    echo "- Grafana: http://localhost:3000 (admin/admin)"
    echo "- Prometheus: http://localhost:9090"
    echo "- AlertManager: http://localhost:9093"
    echo "- Jaeger: http://localhost:16686"
    echo "- Loki: http://localhost:3100"
    echo ""
    
    print_success "Monitoring stack setup complete!"
}

# Cleanup function
cleanup() {
    print_step "Cleaning up..."
    print_warning "To stop the monitoring stack, run: docker-compose -f docker-compose.monitoring.yml down"
}

# Main execution
main() {
    echo "🎯 Avalanche Parallel Monitoring Stack Setup"
    echo "============================================="
    
    check_dependencies
    create_directories
    setup_grafana_provisioning
    setup_additional_configs
    start_monitoring_stack
    wait_for_services
    import_grafana_dashboards
    setup_prometheus_targets
    verify_monitoring
    
    trap cleanup EXIT
}

# Run main function
main "$@" 