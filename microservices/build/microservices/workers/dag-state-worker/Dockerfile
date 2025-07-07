# Multi-stage build for dag-state-worker
FROM golang:1.21-alpine AS builder

# Install dependencies
RUN apk add --no-cache git ca-certificates

WORKDIR /build

# Copy root go.mod and go.sum
COPY build/go.mod build/go.sum ./

# Copy microservices go.mod and go.sum
COPY build/microservices/go.mod build/microservices/go.sum ./microservices/
WORKDIR /build/microservices
RUN go mod download

# Create directories
RUN mkdir -p workers

# Copy source code
COPY build/microservices/workers ./workers

# Build the worker
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o dag-state-worker ./workers/dag-state-worker/cmd

# Final stage
FROM alpine:latest

# Install ca-certificates and curl for health checks
RUN apk --no-cache add ca-certificates curl

WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /build/microservices/dag-state-worker .

# Create log directory
RUN mkdir -p /var/log

# Expose metrics port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the worker
CMD ["./dag-state-worker"]
