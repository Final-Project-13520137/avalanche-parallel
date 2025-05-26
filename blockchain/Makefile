.PHONY: build run test clean docker-build docker-run docker-stop help

# Variables
BINARY_NAME=avalanche-blockchain
DOCKER_IMAGE=avalanche/blockchain:latest
GO=go
GOFLAGS=-v

# Default target
default: build

## help: Show this help message
help:
	@echo "Available targets:"
	@grep -E '^##' Makefile | sed 's/## //'

## build: Build the blockchain binary
build:
	@echo "Building blockchain..."
	$(GO) build $(GOFLAGS) -o $(BINARY_NAME) .

## run: Run the blockchain with default settings
run: build
	@echo "Running blockchain..."
	./$(BINARY_NAME)

## run-traditional: Run with traditional consensus
run-traditional: build
	@echo "Running blockchain with traditional consensus..."
	./$(BINARY_NAME) --consensus=traditional

## run-microservices: Run with microservices consensus
run-microservices: build
	@echo "Running blockchain with microservices consensus..."
	./$(BINARY_NAME) --consensus=microservices --microservice-url=http://localhost:8080

## run-hybrid: Run with hybrid consensus
run-hybrid: build
	@echo "Running blockchain with hybrid consensus..."
	./$(BINARY_NAME) --consensus=hybrid --microservice-url=http://localhost:8080

## test: Run tests
test:
	@echo "Running tests..."
	$(GO) test ./... -v

## test-coverage: Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	$(GO) test ./... -v -cover -coverprofile=coverage.out
	$(GO) tool cover -html=coverage.out -o coverage.html

## clean: Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -f $(BINARY_NAME)
	rm -f coverage.out coverage.html
	rm -rf data/

## docker-build: Build Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE) .

## docker-run: Run blockchain in Docker
docker-run: docker-build
	@echo "Running blockchain in Docker..."
	docker run -d \
		--name avalanche-blockchain \
		-p 9650:9650 \
		-p 9651:9651 \
		-v avalanche-blockchain-data:/data \
		$(DOCKER_IMAGE)

## docker-stop: Stop and remove Docker container
docker-stop:
	@echo "Stopping Docker container..."
	docker stop avalanche-blockchain || true
	docker rm avalanche-blockchain || true

## docker-compose-up: Start all services with docker-compose
docker-compose-up:
	@echo "Starting all services..."
	docker-compose up -d

## docker-compose-down: Stop all services
docker-compose-down:
	@echo "Stopping all services..."
	docker-compose down

## docker-compose-logs: Show logs from all services
docker-compose-logs:
	docker-compose logs -f

## example: Run the example client
example: build
	@echo "Running example client..."
	cd example && go run main.go

## fmt: Format Go code
fmt:
	@echo "Formatting code..."
	$(GO) fmt ./...

## lint: Run linter
lint:
	@echo "Running linter..."
	golangci-lint run

## deps: Download dependencies
deps:
	@echo "Downloading dependencies..."
	$(GO) mod download
	$(GO) mod tidy

## install: Install the binary
install: build
	@echo "Installing binary..."
	$(GO) install

## monitoring-setup: Setup monitoring configuration
monitoring-setup:
	@echo "Setting up monitoring..."
	mkdir -p monitoring/grafana/dashboards
	mkdir -p monitoring/grafana/datasources
	cp monitoring-templates/* monitoring/ 2>/dev/null || true

## benchmark: Run benchmarks
benchmark:
	@echo "Running benchmarks..."
	$(GO) test -bench=. -benchmem ./...

## generate: Generate code (if needed)
generate:
	@echo "Generating code..."
	$(GO) generate ./...

# Development helpers

## dev-setup: Setup development environment
dev-setup: deps monitoring-setup
	@echo "Development environment ready!"

## dev-run: Run with hot reload (requires air)
dev-run:
	@echo "Running with hot reload..."
	air

## check: Run all checks (fmt, lint, test)
check: fmt lint test
	@echo "All checks passed!"

# Production helpers

## prod-build: Build for production
prod-build:
	@echo "Building for production..."
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GO) build \
		-ldflags="-w -s" \
		-o $(BINARY_NAME)-linux-amd64 .

## prod-docker: Build production Docker image
prod-docker:
	@echo "Building production Docker image..."
	docker build -t $(DOCKER_IMAGE) -f Dockerfile.prod .

# Utility targets

## version: Show version information
version:
	@echo "Blockchain version: 1.0.0"
	@$(GO) version

## stats: Show code statistics
stats:
	@echo "Code statistics:"
	@find . -name '*.go' -not -path "./vendor/*" | xargs wc -l 