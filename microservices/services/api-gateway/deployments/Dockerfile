# Multi-stage build for api-gateway
FROM golang:1.21-alpine AS builder

# Install dependencies
RUN apk add --no-cache git ca-certificates build-base

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Force Go to use Go 1.21 and download dependencies
ENV GOTOOLCHAIN=local
ENV GO111MODULE=on

# Download dependencies and update go.sum if needed
RUN go mod download || (go mod tidy && go mod download)

# Copy source code
COPY . .

# Build the service
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o api-gateway-binary ./api-gateway/cmd

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/api-gateway-binary ./api-gateway

# Expose ports
EXPOSE 9650
EXPOSE 9750

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9650/health || exit 1

# Run the service
CMD ["./api-gateway"]
