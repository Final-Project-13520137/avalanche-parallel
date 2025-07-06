# 🚀 Avalanche Parallel Processing Services

Panduan lengkap untuk setup, konfigurasi, dan penggunaan microservices dalam sistem Avalanche Parallel Processing.

## 📑 Daftar Isi
- [Struktur Services](#-struktur-services)
- [Prasyarat](#-prasyarat)
- [Langkah-langkah Setup](#-langkah-langkah-setup)
- [Konfigurasi Services](#-konfigurasi-services)
- [Menjalankan Services](#-menjalankan-services)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)

## 📂 Struktur Services

```
services/
├── api-gateway/           # API Gateway Service
│   ├── cmd/              # Entry point
│   ├── internal/         # Internal packages
│   ├── pkg/              # Public packages
│   └── deployments/      # Deployment configs
├── consensus/            # Consensus Service
│   ├── cmd/
│   ├── internal/
│   │   ├── processor/    # Consensus processing
│   │   ├── validator/    # Validation logic
│   │   └── state/       # State management
│   └── pkg/
├── validator/            # Validator Service
│   ├── cmd/
│   ├── internal/
│   │   ├── validation/   # Validation logic
│   │   ├── signature/    # Signature verification
│   │   └── rules/       # Validation rules
│   └── pkg/
├── dag/                  # DAG Service
│   ├── cmd/
│   ├── internal/
│   │   ├── graph/       # DAG operations
│   │   ├── storage/     # Graph storage
│   │   └── sync/        # Synchronization
│   └── pkg/
└── state/               # State Service
    ├── cmd/
    ├── internal/
    │   ├── store/       # State storage
    │   ├── updates/     # State updates
    │   └── sync/        # State sync
    └── pkg/
```

## ⚙️ Prasyarat

1. **Development Tools**
   ```bash
   # Go 1.21+
   go version

   # Protocol Buffers
   protoc --version

   # Docker & Docker Compose
   docker --version
   docker-compose --version
   ```

2. **Dependencies**
   ```bash
   # Install Go dependencies
   go mod download

   # Install protoc plugins
   go install google.golang.org/protobuf/cmd/protoc-gen-go
   go install google.golang.org/grpc/cmd/protoc-gen-go-grpc
   ```

## 🔧 Langkah-langkah Setup

### 1. Generate Protocol Buffers

```bash
# Windows
.\scripts\generator\generate-protos.ps1

# Linux/macOS
./scripts/generator/generate-protos.sh
```

### 2. Setup Database

```bash
# Create database schema
cd sql
./init-database.sh

# Verify tables
psql -h localhost -U avalanche -d avalanche -c "\dt"
```

### 3. Setup Redis Queues

```bash
# Create required queues
redis-cli << EOF
DEL consensus_tasks validation_tasks dag_state_tasks
EOF
```

### 4. Build Services

```bash
# Build all services
cd services

# API Gateway
cd api-gateway
go build -o bin/api-gateway ./cmd

# Consensus Service
cd ../consensus
go build -o bin/consensus-service ./cmd

# Validator Service
cd ../validator
go build -o bin/validator-service ./cmd

# DAG Service
cd ../dag
go build -o bin/dag-service ./cmd

# State Service
cd ../state
go build -o bin/state-service ./cmd
```

## ⚡ Konfigurasi Services

### 1. API Gateway
```yaml
# config/api-gateway.yaml
server:
  port: 9650
  metrics_port: 9750

redis:
  url: redis://localhost:6379
  password: ""

queues:
  consensus: consensus_tasks
  validator: validation_tasks
  dag_state: dag_state_tasks
```

### 2. Consensus Service
```yaml
# config/consensus.yaml
server:
  port: 8080
  metrics_port: 8081

redis:
  url: redis://localhost:6379
  password: ""

processing:
  batch_size: 100
  workers: 5
  timeout: 30s
```

### 3. Validator Service
```yaml
# config/validator.yaml
server:
  port: 8082
  metrics_port: 8083

redis:
  url: redis://localhost:6379
  password: ""

validation:
  batch_size: 200
  workers: 10
  timeout: 15s
```

### 4. DAG Service
```yaml
# config/dag.yaml
server:
  port: 8084
  metrics_port: 8085

postgres:
  host: localhost
  port: 5432
  user: avalanche
  password: avalanche123
  database: avalanche

graph:
  cache_size: 1000
  sync_interval: 5s
```

### 5. State Service
```yaml
# config/state.yaml
server:
  port: 8086
  metrics_port: 8087

postgres:
  host: localhost
  port: 5432
  user: avalanche
  password: avalanche123
  database: avalanche

state:
  cache_size: 5000
  sync_interval: 3s
```

## 🚀 Menjalankan Services

### 1. Start Infrastructure

```bash
# Start Redis & PostgreSQL
docker-compose -f docker-compose.infra.yml up -d
```

### 2. Start Individual Services

```bash
# API Gateway
./bin/api-gateway --config config/api-gateway.yaml

# Consensus Service
./bin/consensus-service --config config/consensus.yaml

# Validator Service
./bin/validator-service --config config/validator.yaml

# DAG Service
./bin/dag-service --config config/dag.yaml

# State Service
./bin/state-service --config config/state.yaml
```

### 3. Start All Services

```bash
# Windows
.\scripts\deployment\deploy-docker.ps1 -Build

# Linux/macOS
./scripts/deployment/deploy-docker.sh --build
```

## 📊 Monitoring

### 1. Service Metrics
- API Gateway: http://localhost:9750/metrics
- Consensus: http://localhost:8081/metrics
- Validator: http://localhost:8083/metrics
- DAG: http://localhost:8085/metrics
- State: http://localhost:8087/metrics

### 2. Grafana Dashboards
- Services Overview: http://localhost:3000/d/services
- Queue Metrics: http://localhost:3000/d/queues
- System Metrics: http://localhost:3000/d/system

### 3. Log Monitoring
```bash
# View service logs
docker-compose logs -f [service-name]

# View specific service logs
docker-compose logs -f api-gateway
docker-compose logs -f consensus-service
```

## ❗ Troubleshooting

### 1. Service Issues
```bash
# Check service status
docker-compose ps

# Check service logs
docker-compose logs -f [service-name]

# Restart service
docker-compose restart [service-name]
```

### 2. Database Issues
```bash
# Check PostgreSQL connection
psql -h localhost -U avalanche -d avalanche -c "SELECT 1"

# Check Redis connection
redis-cli ping
```

### 3. Common Problems

1. **Service Won't Start**
   - Check logs: `docker-compose logs [service-name]`
   - Verify config: `cat config/[service].yaml`
   - Check port conflicts: `netstat -an | grep [port]`

2. **Performance Issues**
   - Check resource usage: `docker stats`
   - Monitor queue length: `redis-cli LLEN [queue_name]`
   - Check connection count: `netstat -an | grep ESTABLISHED | wc -l`

3. **Data Sync Issues**
   - Check state sync logs
   - Verify database connections
   - Check network connectivity

### 4. Recovery Steps

1. **Service Recovery**
   ```bash
   # Stop service
   docker-compose stop [service-name]
   
   # Remove container
   docker-compose rm -f [service-name]
   
   # Start service
   docker-compose up -d [service-name]
   ```

2. **Data Recovery**
   ```bash
   # Backup database
   pg_dump -h localhost -U avalanche avalanche > backup.sql
   
   # Restore database
   psql -h localhost -U avalanche avalanche < backup.sql
   ```

3. **Full System Recovery**
   ```bash
   # Stop all services
   docker-compose down
   
   # Clean volumes
   docker-compose down -v
   
   # Rebuild and start
   docker-compose up -d --build
   ``` 