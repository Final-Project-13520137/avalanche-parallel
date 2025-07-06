# Multi-stage build for consensus-worker
FROM golang:1.21-alpine AS builder

# Install dependencies
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the worker
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o consensus-worker ./workers/consensus-worker/cmd

# Final stage
FROM alpine:latest

# Install ca-certificates and curl for health checks
RUN apk --no-cache add ca-certificates curl

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/consensus-worker .

# Create log directory
RUN mkdir -p /var/log

# Expose metrics port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the worker
CMD ["./consensus-worker"]
