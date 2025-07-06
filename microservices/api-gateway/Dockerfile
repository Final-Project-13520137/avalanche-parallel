FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the API gateway
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o api-gateway ./api-gateway/cmd

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates curl
WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/api-gateway .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9750/health || exit 1

CMD ["./api-gateway"] 