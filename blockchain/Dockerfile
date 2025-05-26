# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git gcc musl-dev

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o avalanche-blockchain .

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1000 -S avalanche && \
    adduser -u 1000 -S avalanche -G avalanche

# Set working directory
WORKDIR /home/avalanche

# Copy binary from builder
COPY --from=builder /app/avalanche-blockchain .

# Create data directory
RUN mkdir -p data && chown -R avalanche:avalanche data

# Switch to non-root user
USER avalanche

# Expose ports
EXPOSE 9650 9651

# Set default environment variables
ENV CONSENSUS_MODE=hybrid \
    NETWORK_MODE=mainnet \
    DATA_DIR=./data \
    API_PORT=9650 \
    P2P_PORT=9651 \
    MICROSERVICE_URL=http://consensus-service:8080

# Run the blockchain
ENTRYPOINT ["./avalanche-blockchain"]

# Default arguments (can be overridden)
CMD ["--consensus=${CONSENSUS_MODE}", \
     "--network=${NETWORK_MODE}", \
     "--datadir=${DATA_DIR}", \
     "--apiport=${API_PORT}", \
     "--p2pport=${P2P_PORT}", \
     "--microservice-url=${MICROSERVICE_URL}"] 