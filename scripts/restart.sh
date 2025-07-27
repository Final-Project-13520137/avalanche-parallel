#!/bin/bash

# Stop and remove containers, networks, and volumes
echo "Stopping and removing existing containers..."
docker-compose down -v

# Cleanup any dangling volumes
echo "Cleaning up volumes..."
docker volume prune -f

# Build images from scratch
echo "Building images..."
docker-compose build --no-cache

# Start services with 1 worker initially
echo "Starting services..."
docker-compose up -d

# Wait for services to initialize
echo "Waiting for services to initialize (30 seconds)..."
sleep 30

# Scale worker service to 3 instances
echo "Scaling worker service to 3 instances..."
docker-compose up -d --scale worker=3

echo "Setup complete!"
echo "Access the services at:"
echo "  - Avalanche Node: http://localhost:9650/ext/info"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3000 (admin/admin)" 