# Docker Build Troubleshooting Guide

## Issue Description
The error occurs when trying to build Docker images for the Avalanche microservices:
```
❌ Fallback build also failed
failed to solve: golang:1.22-alpine: failed to resolve source metadata for docker.io/library/golang:1.22-alpine: error getting credentials - err: exit status 1
```

## Root Causes
1. **Docker Credential Issues**: Corrupted or invalid Docker credentials
2. **Network Connectivity**: Firewall or proxy blocking Docker Hub access
3. **Docker Hub Rate Limiting**: Exceeded pull limits for anonymous users
4. **Base Image Availability**: Specific image versions may be temporarily unavailable
5. **Docker Daemon Issues**: Docker service problems or configuration issues

## Quick Fix Solutions

### Option 1: Quick Fix Script (Recommended)
Run the quick fix script that updates Dockerfiles to use more stable base images:

**Windows:**
```powershell
.\quick-fix-dockerfiles.ps1
```

**Linux/Mac:**
```bash
./quick-fix-dockerfiles.sh
```

### Option 2: Manual Dockerfile Updates
Update the base images in all Dockerfiles:

**Before:**
```dockerfile
FROM golang:1.22-alpine AS builder
# ...
FROM alpine:latest
```

**After:**
```dockerfile
FROM golang:1.21-alpine AS builder
# ...
FROM alpine:3.18
```

### Option 3: Full Fix Script
For comprehensive troubleshooting, run the full fix script:

**Windows:**
```powershell
.\fix-docker-build.ps1
```

**Linux/Mac:**
```bash
./fix-docker-build.sh
```

## Manual Troubleshooting Steps

### 1. Clear Docker Credentials
```bash
# Logout from Docker Hub
docker logout

# Clear credential manager (Windows)
cmdkey /list | findstr "docker" | ForEach-Object {
    $credName = ($_ -split '\s+')[1]
    cmdkey /delete:$credName
}

# Clear Docker config (Linux/Mac)
rm -rf ~/.docker/config.json
```

### 2. Clean Docker System
```bash
# Remove unused images, containers, networks
docker system prune -a

# Clear build cache
docker builder prune

# Remove all unused volumes
docker volume prune
```

### 3. Pull Base Images Manually
```bash
# Pull required base images
docker pull golang:1.21-alpine
docker pull golang:1.22-alpine
docker pull alpine:3.18
docker pull alpine:latest
docker pull redis:7-alpine
docker pull postgres:15-alpine
```

### 4. Test Network Connectivity
```bash
# Test Docker Hub connectivity
curl -I https://registry-1.docker.io/v2/

# Test specific image pull
docker pull hello-world
```

### 5. Check Docker Daemon
```bash
# Check Docker service status
docker version
docker info

# Restart Docker service
# Windows: Restart Docker Desktop
# Linux: sudo systemctl restart docker
```

## Alternative Solutions

### 1. Use Different Base Images
If `golang:1.22-alpine` is problematic, try:
- `golang:1.21-alpine`
- `golang:1.20-alpine`
- `golang:1.19-alpine`

### 2. Use Different Alpine Versions
If `alpine:latest` is problematic, try:
- `alpine:3.18`
- `alpine:3.17`
- `alpine:3.16`

### 3. Use Different Registry Mirrors
Configure Docker to use alternative registries:

**Windows (Docker Desktop):**
1. Open Docker Desktop Settings
2. Go to Docker Engine
3. Add registry mirrors:
```json
{
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://registry.docker-cn.com"
  ]
}
```

**Linux:**
Edit `/etc/docker/daemon.json`:
```json
{
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://registry.docker-cn.com"
  ]
}
```

### 4. Build Without Cache
```bash
docker-compose -f docker-compose.worker-pools.yml build --no-cache
```

### 5. Use BuildKit
Enable BuildKit for better build performance:
```bash
export DOCKER_BUILDKIT=1
docker-compose -f docker-compose.worker-pools.yml build
```

## Testing the Fix

### 1. Test with Simplified Compose
```bash
# Use the test compose file
docker-compose -f docker-compose.test.yml up --build
```

### 2. Test Individual Services
```bash
# Test one service at a time
docker-compose -f docker-compose.worker-pools.yml build consensus-worker
docker-compose -f docker-compose.worker-pools.yml build api-gateway
```

### 3. Verify Images
```bash
# Check if images were built successfully
docker images | grep avalanche
```

## Prevention

### 1. Use Specific Image Tags
Instead of `latest`, use specific versions:
```dockerfile
FROM golang:1.21.5-alpine
FROM alpine:3.18.4
```

### 2. Pin Dependencies
Use exact versions in go.mod:
```go
require (
    github.com/go-redis/redis/v8 v8.11.5
    github.com/prometheus/client_golang v1.16.0
)
```

### 3. Regular Maintenance
```bash
# Regular cleanup
docker system prune -f
docker builder prune -f

# Update base images periodically
docker pull golang:1.21-alpine
docker pull alpine:3.18
```

## Common Error Messages and Solutions

| Error | Solution |
|-------|----------|
| `failed to resolve source metadata` | Clear credentials, check network |
| `error getting credentials` | Run `docker logout`, clear credential manager |
| `rate limit exceeded` | Login to Docker Hub or use registry mirrors |
| `connection timeout` | Check firewall, use VPN if needed |
| `manifest not found` | Use different image tag or version |

## Getting Help

If the issue persists:

1. **Check Docker Hub Status**: https://status.docker.com/
2. **Check Network**: Test connectivity to registry-1.docker.io
3. **Check Logs**: Review Docker daemon logs
4. **Try Alternative Images**: Use different base image versions
5. **Use Local Build**: Build images locally instead of pulling

## Files Created by Fix Scripts

- `Dockerfile.alternative` - Alternative Dockerfiles with stable base images
- `docker-compose.test.yml` - Simplified compose file for testing
- `*.backup` - Backup files of original configurations

## Success Indicators

✅ Docker images build successfully
✅ Services start without errors
✅ Health checks pass
✅ No credential or network errors in logs 