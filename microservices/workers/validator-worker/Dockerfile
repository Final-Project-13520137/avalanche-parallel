FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && \
    go get -u github.com/go-redis/redis/v8@v8.11.5 && \
    go get -u github.com/prometheus/client_golang@v1.16.0 && \
    go get -u github.com/golang/protobuf/proto@v1.5.3 && \
    go get -u google.golang.org/protobuf@v1.30.0 && \
    go get -u golang.org/x/sys@v0.8.0 && \
    go mod tidy

# Copy source code
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o validator-worker cmd/main.go

# Create final image
FROM alpine:latest

# Install curl for healthcheck
RUN apk add --no-cache curl

# Copy binary from builder
COPY --from=builder /app/validator-worker .

# Expose metrics port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

# Run
CMD ["./validator-worker"]
