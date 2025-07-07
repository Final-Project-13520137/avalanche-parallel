# Multi-stage build for validator-worker
FROM golang:1.21-alpine AS builder

# Install dependencies
RUN apk add --no-cache git ca-certificates

WORKDIR /build

# Copy the entire project
COPY . .

# Set working directory to validator worker
WORKDIR /build/microservices/workers/validator-worker

# Download dependencies and tidy up modules
RUN go mod download && go mod tidy

# Build the worker
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o validator-worker ./cmd

# Final stage
FROM alpine:latest

# Install ca-certificates and curl for health checks
RUN apk --no-cache add ca-certificates curl

WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /build/microservices/workers/validator-worker/validator-worker .

# Create log directory
RUN mkdir -p /var/log

# Expose metrics port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the worker
CMD ["./validator-worker"]
