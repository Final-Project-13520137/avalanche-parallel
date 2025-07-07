FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o api-gateway cmd/main.go

# Create final image
FROM alpine:latest

# Copy binary from builder
COPY --from=builder /build/api-gateway /app/api-gateway

# Set working directory
WORKDIR /app

# Expose ports
EXPOSE 9650 9750

# Run
CMD ["./api-gateway"] 