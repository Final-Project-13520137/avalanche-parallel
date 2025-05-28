FROM golang:1.19-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base git curl

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Make sure avalanche-parallel exists
ARG AVALANCHE_PARALLEL_PATH
RUN mkdir -p /go/src/github.com/Final-Project-13520137
RUN ln -s /avalanche-parallel /go/src/github.com/Final-Project-13520137/avalanche-parallel

# Build the blockchain
RUN go build -o /bin/avalanche-blockchain ./cmd/blockchain

# Create a minimal image
FROM alpine:3.18

RUN apk add --no-cache ca-certificates curl

WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /bin/avalanche-blockchain /app/avalanche-blockchain

# Expose API port
EXPOSE 8545

# Set environment variables
ENV LOG_LEVEL=info
ENV PARALLELISM=4
ENV API_PORT=8545

# Run the blockchain
ENTRYPOINT ["/app/avalanche-blockchain", "--log-level=${LOG_LEVEL}", "--parallelism=${PARALLELISM}", "--api-port=${API_PORT}"] 