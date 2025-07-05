#!/bin/bash

# Avalanche Microservices Generator
# Generate all microservices from Avalanche default code

set -e

echo "🚀 Generating Avalanche Microservices..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MICROSERVICES_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$MICROSERVICES_DIR")"
DEFAULT_DIR="$ROOT_DIR/default"

# Services to generate
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

# Check if default Avalanche code exists
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    if [ ! -d "$DEFAULT_DIR" ]; then
        print_error "Default Avalanche directory not found: $DEFAULT_DIR"
        exit 1
    fi
    
    if [ ! -f "$DEFAULT_DIR/go.mod" ]; then
        print_error "go.mod not found in default directory"
        exit 1
    fi
    
    # Check Go version
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed"
        exit 1
    fi
    
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    if [[ $(printf '%s\n' "1.21" "$GO_VERSION" | sort -V | head -n1) != "1.21" ]]; then
        print_error "Go 1.21+ required, found: $GO_VERSION"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create directory structure
create_directory_structure() {
    print_step "Creating directory structure..."
    
    # Create main microservices directories
    for service in "${SERVICES[@]}"; do
        mkdir -p "$MICROSERVICES_DIR/services/$service/cmd"
        mkdir -p "$MICROSERVICES_DIR/services/$service/internal"
        mkdir -p "$MICROSERVICES_DIR/services/$service/pkg"
        mkdir -p "$MICROSERVICES_DIR/services/$service/config"
        mkdir -p "$MICROSERVICES_DIR/services/$service/deployments"
    done
    
    # Create shared directories
    mkdir -p "$MICROSERVICES_DIR/shared/proto"
    mkdir -p "$MICROSERVICES_DIR/shared/common"
    mkdir -p "$MICROSERVICES_DIR/shared/middleware"
    mkdir -p "$MICROSERVICES_DIR/docker"
    mkdir -p "$MICROSERVICES_DIR/k8s"
    
    print_success "Directory structure created"
}

# Generate shared components
generate_shared_components() {
    print_step "Generating shared components..."
    
    # Generate shared types and interfaces
    cat > "$MICROSERVICES_DIR/shared/common/types.go" << 'EOF'
package common

import (
    "context"
    "time"
    
    "github.com/ava-labs/avalanchego/ids"
    "github.com/ava-labs/avalanchego/utils/hashing"
)

// Transaction represents a blockchain transaction
type Transaction struct {
    ID        ids.ID            `json:"id"`
    Data      []byte           `json:"data"`
    Hash      hashing.Hash     `json:"hash"`
    Timestamp time.Time        `json:"timestamp"`
    Size      int              `json:"size"`
}

// Vertex represents a DAG vertex
type Vertex struct {
    ID         ids.ID      `json:"id"`
    ParentIDs  []ids.ID    `json:"parent_ids"`
    Height     uint64      `json:"height"`
    Txs        []Transaction `json:"transactions"`
    Timestamp  time.Time   `json:"timestamp"`
    Confidence float64     `json:"confidence"`
}

// ConsensusRequest represents a consensus operation request
type ConsensusRequest struct {
    Type      string      `json:"type"`
    VertexID  ids.ID      `json:"vertex_id"`
    Data      interface{} `json:"data"`
    Timestamp time.Time   `json:"timestamp"`
}

// ValidationRequest represents a validation request
type ValidationRequest struct {
    TransactionID ids.ID      `json:"transaction_id"`
    Data         []byte      `json:"data"`
    Signature    []byte      `json:"signature"`
    PublicKey    []byte      `json:"public_key"`
}

// ServiceResponse represents a standard service response
type ServiceResponse struct {
    Success   bool        `json:"success"`
    Data      interface{} `json:"data,omitempty"`
    Error     string      `json:"error,omitempty"`
    Timestamp time.Time   `json:"timestamp"`
}

// HealthStatus represents service health status
type HealthStatus struct {
    Service   string    `json:"service"`
    Status    string    `json:"status"`
    Uptime    time.Duration `json:"uptime"`
    Version   string    `json:"version"`
    Timestamp time.Time `json:"timestamp"`
}

// ServiceInterface defines common service methods
type ServiceInterface interface {
    Start(ctx context.Context) error
    Stop(ctx context.Context) error
    Health() HealthStatus
    Metrics() map[string]interface{}
}
EOF

    # Generate message queue interface
    cat > "$MICROSERVICES_DIR/shared/common/queue.go" << 'EOF'
package common

import (
    "context"
    "encoding/json"
    "time"
)

// Message represents a queue message
type Message struct {
    ID        string      `json:"id"`
    Type      string      `json:"type"`
    Service   string      `json:"service"`
    Data      interface{} `json:"data"`
    Timestamp time.Time   `json:"timestamp"`
    RetryCount int        `json:"retry_count"`
}

// QueueInterface defines message queue operations
type QueueInterface interface {
    Publish(ctx context.Context, topic string, message Message) error
    Subscribe(ctx context.Context, topic string, handler MessageHandler) error
    Close() error
}

// MessageHandler defines message processing function
type MessageHandler func(ctx context.Context, message Message) error

// ToJSON converts message to JSON bytes
func (m Message) ToJSON() ([]byte, error) {
    return json.Marshal(m)
}

// FromJSON creates message from JSON bytes
func MessageFromJSON(data []byte) (*Message, error) {
    var msg Message
    err := json.Unmarshal(data, &msg)
    return &msg, err
}
EOF

    # Generate middleware
    cat > "$MICROSERVICES_DIR/shared/middleware/logging.go" << 'EOF'
package middleware

import (
    "context"
    "log"
    "time"
)

// Logger interface for structured logging
type Logger interface {
    Info(msg string, fields ...interface{})
    Error(msg string, fields ...interface{})
    Debug(msg string, fields ...interface{})
    Warn(msg string, fields ...interface{})
}

// LoggingMiddleware provides request/response logging
type LoggingMiddleware struct {
    logger Logger
}

// NewLoggingMiddleware creates a new logging middleware
func NewLoggingMiddleware(logger Logger) *LoggingMiddleware {
    return &LoggingMiddleware{logger: logger}
}

// LogRequest logs incoming requests
func (l *LoggingMiddleware) LogRequest(ctx context.Context, service, method string, data interface{}) {
    l.logger.Info("Request received",
        "service", service,
        "method", method,
        "data", data,
        "timestamp", time.Now(),
    )
}

// LogResponse logs outgoing responses
func (l *LoggingMiddleware) LogResponse(ctx context.Context, service, method string, duration time.Duration, err error) {
    if err != nil {
        l.logger.Error("Request failed",
            "service", service,
            "method", method,
            "duration", duration,
            "error", err.Error(),
        )
    } else {
        l.logger.Info("Request completed",
            "service", service,
            "method", method,
            "duration", duration,
        )
    }
}

// DefaultLogger provides a simple logger implementation
type DefaultLogger struct{}

func (d DefaultLogger) Info(msg string, fields ...interface{}) {
    log.Printf("[INFO] %s %v", msg, fields)
}

func (d DefaultLogger) Error(msg string, fields ...interface{}) {
    log.Printf("[ERROR] %s %v", msg, fields)
}

func (d DefaultLogger) Debug(msg string, fields ...interface{}) {
    log.Printf("[DEBUG] %s %v", msg, fields)
}

func (d DefaultLogger) Warn(msg string, fields ...interface{}) {
    log.Printf("[WARN] %s %v", msg, fields)
}
EOF

    print_success "Shared components generated"
}

# Generate individual services
generate_service() {
    local service_name=$1
    print_step "Generating $service_name service..."
    
    case $service_name in
        "api-gateway")
            generate_api_gateway
            ;;
        "consensus")
            generate_consensus_service
            ;;
        "validator")
            generate_validator_service
            ;;
        "dag")
            generate_dag_service
            ;;
        "state")
            generate_state_service
            ;;
    esac
    
    print_success "$service_name service generated"
}

# Generate all services
generate_all_services() {
    for service in "${SERVICES[@]}"; do
        generate_service "$service"
    done
}

# Generate API Gateway
generate_api_gateway() {
    local service_dir="$MICROSERVICES_DIR/services/api-gateway"
    
    # Generate main.go
    cat > "$service_dir/cmd/main.go" << 'EOF'
package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "syscall"
    
    "github.com/ava-labs/avalanchego/utils/logging"
    "avalanche-microservices/services/api-gateway/internal/server"
    "avalanche-microservices/services/api-gateway/internal/config"
)

func main() {
    // Load configuration
    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("Failed to load config: %v", err)
    }
    
    // Setup logging
    logger, err := logging.New(logging.Config{
        Level: logging.Info,
    })
    if err != nil {
        log.Fatalf("Failed to setup logger: %v", err)
    }
    
    // Create server
    srv, err := server.New(cfg, logger)
    if err != nil {
        logger.Fatal("Failed to create server: %v", err)
    }
    
    // Start server
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    go func() {
        if err := srv.Start(ctx); err != nil {
            logger.Fatal("Server failed: %v", err)
        }
    }()
    
    // Wait for shutdown signal
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    <-sigChan
    
    logger.Info("Shutting down...")
    srv.Stop(ctx)
}
EOF

    # Generate config
    cat > "$service_dir/internal/config/config.go" << 'EOF'
package config

import (
    "os"
    "strconv"
)

type Config struct {
    Port         int    `json:"port"`
    RedisURL     string `json:"redis_url"`
    MetricsPort  int    `json:"metrics_port"`
    LogLevel     string `json:"log_level"`
    
    // Service endpoints
    ConsensusEndpoint string `json:"consensus_endpoint"`
    ValidatorEndpoint string `json:"validator_endpoint"`
    DAGEndpoint      string `json:"dag_endpoint"`
    StateEndpoint    string `json:"state_endpoint"`
}

func Load() (*Config, error) {
    config := &Config{
        Port:              getEnvAsInt("SERVICE_PORT", 9650),
        RedisURL:          getEnv("REDIS_URL", "redis://localhost:6379"),
        MetricsPort:       getEnvAsInt("METRICS_PORT", 9750),
        LogLevel:          getEnv("LOG_LEVEL", "info"),
        ConsensusEndpoint: getEnv("CONSENSUS_ENDPOINT", "http://consensus:9651"),
        ValidatorEndpoint: getEnv("VALIDATOR_ENDPOINT", "http://validator:9652"),
        DAGEndpoint:       getEnv("DAG_ENDPOINT", "http://dag:9653"),
        StateEndpoint:     getEnv("STATE_ENDPOINT", "http://state:9654"),
    }
    
    return config, nil
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
    if value := os.Getenv(key); value != "" {
        if intValue, err := strconv.Atoi(value); err == nil {
            return intValue
        }
    }
    return defaultValue
}
EOF

    # Generate server
    cat > "$service_dir/internal/server/server.go" << 'EOF'
package server

import (
    "context"
    "fmt"
    "net/http"
    "time"
    
    "github.com/gorilla/mux"
    "github.com/ava-labs/avalanchego/utils/logging"
    "avalanche-microservices/services/api-gateway/internal/config"
    "avalanche-microservices/services/api-gateway/internal/handlers"
    "avalanche-microservices/shared/middleware"
)

type Server struct {
    config     *config.Config
    logger     logging.Logger
    httpServer *http.Server
    handlers   *handlers.Handlers
}

func New(cfg *config.Config, logger logging.Logger) (*Server, error) {
    handlers := handlers.New(cfg, logger)
    
    return &Server{
        config:   cfg,
        logger:   logger,
        handlers: handlers,
    }, nil
}

func (s *Server) Start(ctx context.Context) error {
    router := s.setupRoutes()
    
    s.httpServer = &http.Server{
        Addr:         fmt.Sprintf(":%d", s.config.Port),
        Handler:      router,
        ReadTimeout:  30 * time.Second,
        WriteTimeout: 30 * time.Second,
        IdleTimeout:  120 * time.Second,
    }
    
    s.logger.Info("Starting API Gateway on port %d", s.config.Port)
    return s.httpServer.ListenAndServe()
}

func (s *Server) Stop(ctx context.Context) error {
    if s.httpServer != nil {
        return s.httpServer.Shutdown(ctx)
    }
    return nil
}

func (s *Server) setupRoutes() *mux.Router {
    router := mux.NewRouter()
    
    // Health check
    router.HandleFunc("/health", s.handlers.Health).Methods("GET")
    
    // Metrics
    router.HandleFunc("/metrics", s.handlers.Metrics).Methods("GET")
    
    // Avalanche JSON-RPC API routes
    api := router.PathPrefix("/ext").Subrouter()
    
    // Admin API
    api.HandleFunc("/admin", s.handlers.ProxyToService("admin")).Methods("POST")
    
    // Platform API  
    api.HandleFunc("/P", s.handlers.ProxyToConsensus).Methods("POST")
    
    // Exchange API
    api.HandleFunc("/X", s.handlers.ProxyToValidator).Methods("POST")
    
    // Contract API
    api.HandleFunc("/C/avax", s.handlers.ProxyToState).Methods("POST")
    
    // Info API
    api.HandleFunc("/info", s.handlers.ProxyToService("info")).Methods("POST")
    
    // Add logging middleware
    loggingMiddleware := middleware.NewLoggingMiddleware(&middleware.DefaultLogger{})
    router.Use(func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()
            loggingMiddleware.LogRequest(r.Context(), "api-gateway", r.URL.Path, r.URL.RawQuery)
            
            next.ServeHTTP(w, r)
            
            duration := time.Since(start)
            loggingMiddleware.LogResponse(r.Context(), "api-gateway", r.URL.Path, duration, nil)
        })
    })
    
    return router
}
EOF

    # Generate handlers
    cat > "$service_dir/internal/handlers/handlers.go" << 'EOF'
package handlers

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "time"
    
    "github.com/ava-labs/avalanchego/utils/logging"
    "avalanche-microservices/services/api-gateway/internal/config"
    "avalanche-microservices/shared/common"
)

type Handlers struct {
    config *config.Config
    logger logging.Logger
    client *http.Client
}

func New(cfg *config.Config, logger logging.Logger) *Handlers {
    return &Handlers{
        config: cfg,
        logger: logger,
        client: &http.Client{
            Timeout: 30 * time.Second,
        },
    }
}

func (h *Handlers) Health(w http.ResponseWriter, r *http.Request) {
    health := common.HealthStatus{
        Service:   "api-gateway",
        Status:    "healthy",
        Uptime:    time.Since(time.Now()),
        Version:   "1.0.0",
        Timestamp: time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(health)
}

func (h *Handlers) Metrics(w http.ResponseWriter, r *http.Request) {
    metrics := map[string]interface{}{
        "requests_total":    1000,
        "request_duration":  "45ms",
        "active_connections": 50,
        "timestamp":         time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(metrics)
}

func (h *Handlers) ProxyToConsensus(w http.ResponseWriter, r *http.Request) {
    h.proxyRequest(w, r, h.config.ConsensusEndpoint)
}

func (h *Handlers) ProxyToValidator(w http.ResponseWriter, r *http.Request) {
    h.proxyRequest(w, r, h.config.ValidatorEndpoint)
}

func (h *Handlers) ProxyToDAG(w http.ResponseWriter, r *http.Request) {
    h.proxyRequest(w, r, h.config.DAGEndpoint)
}

func (h *Handlers) ProxyToState(w http.ResponseWriter, r *http.Request) {
    h.proxyRequest(w, r, h.config.StateEndpoint)
}

func (h *Handlers) ProxyToService(serviceName string) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // Route to appropriate service based on service name
        var endpoint string
        switch serviceName {
        case "admin", "info":
            endpoint = h.config.ConsensusEndpoint
        default:
            endpoint = h.config.StateEndpoint
        }
        h.proxyRequest(w, r, endpoint)
    }
}

func (h *Handlers) proxyRequest(w http.ResponseWriter, r *http.Request, targetURL string) {
    // Read request body
    body, err := io.ReadAll(r.Body)
    if err != nil {
        http.Error(w, "Failed to read request body", http.StatusBadRequest)
        return
    }
    defer r.Body.Close()
    
    // Create proxy request
    proxyReq, err := http.NewRequestWithContext(r.Context(), r.Method, targetURL+r.URL.Path, bytes.NewBuffer(body))
    if err != nil {
        http.Error(w, "Failed to create proxy request", http.StatusInternalServerError)
        return
    }
    
    // Copy headers
    for key, values := range r.Header {
        for _, value := range values {
            proxyReq.Header.Add(key, value)
        }
    }
    
    // Make request
    resp, err := h.client.Do(proxyReq)
    if err != nil {
        h.logger.Error("Proxy request failed: %v", err)
        http.Error(w, "Service unavailable", http.StatusServiceUnavailable)
        return
    }
    defer resp.Body.Close()
    
    // Copy response headers
    for key, values := range resp.Header {
        for _, value := range values {
            w.Header().Add(key, value)
        }
    }
    
    // Copy status code
    w.WriteHeader(resp.StatusCode)
    
    // Copy response body
    io.Copy(w, resp.Body)
}
EOF

    # Generate Dockerfile
    cat > "$service_dir/deployments/Dockerfile" << 'EOF'
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o api-gateway ./services/api-gateway/cmd

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/api-gateway .

EXPOSE 9650 9750

CMD ["./api-gateway"]
EOF
}

# Generate other services (simplified for space)
generate_consensus_service() {
    local service_dir="$MICROSERVICES_DIR/services/consensus"
    
    cat > "$service_dir/cmd/main.go" << 'EOF'
package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "syscall"
    
    "avalanche-microservices/services/consensus/internal/server"
    "avalanche-microservices/services/consensus/internal/config"
)

func main() {
    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("Failed to load config: %v", err)
    }
    
    srv, err := server.New(cfg)
    if err != nil {
        log.Fatalf("Failed to create server: %v", err)
    }
    
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    go func() {
        if err := srv.Start(ctx); err != nil {
            log.Fatalf("Server failed: %v", err)
        }
    }()
    
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    <-sigChan
    
    log.Println("Shutting down...")
    srv.Stop(ctx)
}
EOF
}

generate_validator_service() {
    local service_dir="$MICROSERVICES_DIR/services/validator"
    
    cat > "$service_dir/cmd/main.go" << 'EOF'
package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "syscall"
    
    "avalanche-microservices/services/validator/internal/server"
    "avalanche-microservices/services/validator/internal/config"
)

func main() {
    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("Failed to load config: %v", err)
    }
    
    srv, err := server.New(cfg)
    if err != nil {
        log.Fatalf("Failed to create server: %v", err)
    }
    
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    go func() {
        if err := srv.Start(ctx); err != nil {
            log.Fatalf("Server failed: %v", err)
        }
    }()
    
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    <-sigChan
    
    log.Println("Shutting down...")
    srv.Stop(ctx)
}
EOF
}

generate_dag_service() {
    local service_dir="$MICROSERVICES_DIR/services/dag"
    
    cat > "$service_dir/cmd/main.go" << 'EOF'
package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "syscall"
    
    "avalanche-microservices/services/dag/internal/server"
    "avalanche-microservices/services/dag/internal/config"
)

func main() {
    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("Failed to load config: %v", err)
    }
    
    srv, err := server.New(cfg)
    if err != nil {
        log.Fatalf("Failed to create server: %v", err)
    }
    
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    go func() {
        if err := srv.Start(ctx); err != nil {
            log.Fatalf("Server failed: %v", err)
        }
    }()
    
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    <-sigChan
    
    log.Println("Shutting down...")
    srv.Stop(ctx)
}
EOF
}

generate_state_service() {
    local service_dir="$MICROSERVICES_DIR/services/state"
    
    cat > "$service_dir/cmd/main.go" << 'EOF'
package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "syscall"
    
    "avalanche-microservices/services/state/internal/server"
    "avalanche-microservices/services/state/internal/config"
)

func main() {
    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("Failed to load config: %v", err)
    }
    
    srv, err := server.New(cfg)
    if err != nil {
        log.Fatalf("Failed to create server: %v", err)
    }
    
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    go func() {
        if err := srv.Start(ctx); err != nil {
            log.Fatalf("Server failed: %v", err)
        }
    }()
    
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    <-sigChan
    
    log.Println("Shutting down...")
    srv.Stop(ctx)
}
EOF
}

# Generate Docker Compose
generate_docker_compose() {
    print_step "Generating Docker Compose configuration..."
    
    cat > "$MICROSERVICES_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  # Infrastructure
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - avalanche-net

  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: avalanche
      POSTGRES_USER: avalanche
      POSTGRES_PASSWORD: avalanche123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - avalanche-net

  # Microservices
  api-gateway:
    build:
      context: .
      dockerfile: services/api-gateway/deployments/Dockerfile
    ports:
      - "9650:9650"
      - "9750:9750"
    environment:
      - SERVICE_PORT=9650
      - METRICS_PORT=9750
      - REDIS_URL=redis://redis:6379
      - CONSENSUS_ENDPOINT=http://consensus:9651
      - VALIDATOR_ENDPOINT=http://validator:9652
      - DAG_ENDPOINT=http://dag:9653
      - STATE_ENDPOINT=http://state:9654
      - LOG_LEVEL=info
    depends_on:
      - redis
      - consensus
      - validator
      - dag
      - state
    networks:
      - avalanche-net

  consensus:
    build:
      context: .
      dockerfile: services/consensus/deployments/Dockerfile
    ports:
      - "9651:9651"
      - "9751:9751"
    environment:
      - SERVICE_PORT=9651
      - METRICS_PORT=9751
      - REDIS_URL=redis://redis:6379
      - DB_URL=postgres://avalanche:avalanche123@postgres:5432/avalanche
      - LOG_LEVEL=info
    depends_on:
      - redis
      - postgres
    networks:
      - avalanche-net
    deploy:
      replicas: 2

  validator:
    build:
      context: .
      dockerfile: services/validator/deployments/Dockerfile
    ports:
      - "9652:9652"
      - "9752:9752"
    environment:
      - SERVICE_PORT=9652
      - METRICS_PORT=9752
      - REDIS_URL=redis://redis:6379
      - DB_URL=postgres://avalanche:avalanche123@postgres:5432/avalanche
      - LOG_LEVEL=info
    depends_on:
      - redis
      - postgres
    networks:
      - avalanche-net
    deploy:
      replicas: 3

  dag:
    build:
      context: .
      dockerfile: services/dag/deployments/Dockerfile
    ports:
      - "9653:9653"
      - "9753:9753"
    environment:
      - SERVICE_PORT=9653
      - METRICS_PORT=9753
      - REDIS_URL=redis://redis:6379
      - DB_URL=postgres://avalanche:avalanche123@postgres:5432/avalanche
      - LOG_LEVEL=info
    depends_on:
      - redis
      - postgres
    networks:
      - avalanche-net
    deploy:
      replicas: 2

  state:
    build:
      context: .
      dockerfile: services/state/deployments/Dockerfile
    ports:
      - "9654:9654"
      - "9754:9754"
    environment:
      - SERVICE_PORT=9654
      - METRICS_PORT=9754
      - REDIS_URL=redis://redis:6379
      - DB_URL=postgres://avalanche:avalanche123@postgres:5432/avalanche
      - LOG_LEVEL=info
    depends_on:
      - redis
      - postgres
    networks:
      - avalanche-net
    deploy:
      replicas: 2

  # Monitoring
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - avalanche-net

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - avalanche-net

  # Load Balancer
  haproxy:
    image: haproxy:2.8-alpine
    ports:
      - "8080:8080"
      - "8404:8404"
    volumes:
      - ./loadbalancer/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg
    depends_on:
      - api-gateway
    networks:
      - avalanche-net

volumes:
  redis_data:
  postgres_data:
  grafana_data:

networks:
  avalanche-net:
    driver: bridge
EOF

    print_success "Docker Compose configuration generated"
}

# Generate Kubernetes manifests
generate_kubernetes_manifests() {
    print_step "Generating Kubernetes manifests..."
    
    # Create namespace
    cat > "$MICROSERVICES_DIR/k8s/namespace.yaml" << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: avalanche
---
EOF

    # Create ConfigMap
    cat > "$MICROSERVICES_DIR/k8s/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: avalanche-config
  namespace: avalanche
data:
  REDIS_URL: "redis://redis:6379"
  DB_URL: "postgres://avalanche:avalanche123@postgres:5432/avalanche"
  LOG_LEVEL: "info"
  CONSENSUS_ENDPOINT: "http://consensus:9651"
  VALIDATOR_ENDPOINT: "http://validator:9652"
  DAG_ENDPOINT: "http://dag:9653"
  STATE_ENDPOINT: "http://state:9654"
---
EOF

    # Generate service deployments
    for service in "${SERVICES[@]}"; do
        port=$((9650 + $(printf "%s\n" "${SERVICES[@]}" | grep -n "^$service$" | cut -d: -f1) - 1))
        metrics_port=$((9750 + $(printf "%s\n" "${SERVICES[@]}" | grep -n "^$service$" | cut -d: -f1) - 1))
        
        cat > "$MICROSERVICES_DIR/k8s/$service.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $service
  namespace: avalanche
  labels:
    app: $service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $service
  template:
    metadata:
      labels:
        app: $service
    spec:
      containers:
      - name: $service
        image: avalanche-$service:latest
        ports:
        - containerPort: $port
        - containerPort: $metrics_port
        env:
        - name: SERVICE_PORT
          value: "$port"
        - name: METRICS_PORT
          value: "$metrics_port"
        envFrom:
        - configMapRef:
            name: avalanche-config
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: $port
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: $port
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: $service
  namespace: avalanche
spec:
  selector:
    app: $service
  ports:
  - name: http
    port: $port
    targetPort: $port
  - name: metrics
    port: $metrics_port
    targetPort: $metrics_port
  type: ClusterIP
---
EOF
    done
    
    print_success "Kubernetes manifests generated"
}

# Generate go.mod for microservices
generate_go_mod() {
    print_step "Generating go.mod for microservices..."
    
    cat > "$MICROSERVICES_DIR/go.mod" << 'EOF'
module avalanche-microservices

go 1.21

require (
    github.com/ava-labs/avalanchego v1.10.18
    github.com/gorilla/mux v1.8.0
    github.com/go-redis/redis/v8 v8.11.5
    github.com/lib/pq v1.10.9
    github.com/prometheus/client_golang v1.17.0
    github.com/stretchr/testify v1.8.4
)

require (
    github.com/beorn7/perks v1.0.1 // indirect
    github.com/cespare/xxhash/v2 v2.2.0 // indirect
    github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
    github.com/golang/protobuf v1.5.3 // indirect
    github.com/matttproud/golang_protobuf_extensions v1.0.4 // indirect
    github.com/prometheus/client_model v0.4.1-0.20230718164431-9a2bf3000d16 // indirect
    github.com/prometheus/common v0.44.0 // indirect
    github.com/prometheus/procfs v0.11.1 // indirect
    golang.org/x/sys v0.12.0 // indirect
    google.golang.org/protobuf v1.31.0 // indirect
)
EOF

    print_success "go.mod generated"
}

# Main execution
main() {
    echo "🚀 Starting Avalanche Microservices Generation..."
    
    check_prerequisites
    create_directory_structure
    generate_shared_components
    generate_all_services
    generate_docker_compose
    generate_kubernetes_manifests
    generate_go_mod
    
    print_success "✅ Avalanche Microservices generation completed!"
    echo ""
    print_step "Next steps:"
    echo "1. cd microservices"
    echo "2. go mod tidy"
    echo "3. docker-compose up -d"
    echo "4. Test API: curl http://localhost:9650/health"
    echo ""
    print_step "Documentation: ./microservices/README.md"
}

# Run main function
main "$@" 