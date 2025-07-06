# Docker Troubleshooting Guide for Avalanche Parallel Processing

This guide provides solutions for common Docker issues encountered when working with the Avalanche Parallel Processing system.

## Common Issues and Solutions

### 1. `invalid containerPort: -` Error

When running `docker-compose -f docker-compose.worker-pools.yml up -d`, you might encounter the following error:

```
failed to solve: invalid containerPort: -
```

**Solution:**

This error typically occurs due to an issue with port mapping in the Docker Compose file. There are several ways to fix this:

1. **Use the simplified version of docker-compose.worker-pools.yml**:
   - This version uses Alpine images instead of building from Dockerfiles
   - Run with: `docker-compose -f docker-compose.worker-pools.yml up -d`

2. **For worker containers, use `expose` instead of `ports`**:
   ```yaml
   expose:
     - 8080
   ```
   instead of:
   ```yaml
   ports:
     - "8080"
   ```

3. **For public-facing services, use proper port mapping with quotes**:
   ```yaml
   ports:
     - "9650:9650"
   ```

### 2. Docker Build Context Issues

When Docker fails to build with errors related to the build context, try:

1. **Clean up Docker resources**:
   ```
   docker system prune -a
   ```

2. **Use the provided helper scripts**:
   - PowerShell: `.\cleanup-worker-pools.ps1` then `.\run-worker-pools.ps1`
   - Bash: `./cleanup-worker-pools.sh` then `./run-worker-pools.sh`

### 3. Slow Docker Builds

If Docker builds are slow:

1. **Use the simplified version** that uses pre-built Alpine images
2. **Optimize your Dockerfiles** to leverage caching
3. **Consider using Docker BuildKit** by setting `DOCKER_BUILDKIT=1`

## Helper Scripts

The following helper scripts are provided to make working with Docker easier:

- `run-worker-pools.ps1` / `run-worker-pools.sh`: Start the worker pools
- `cleanup-worker-pools.ps1` / `cleanup-worker-pools.sh`: Stop and clean up the worker pools

## Complete Reset

If you need to completely reset your Docker environment:

```bash
# Stop all containers
docker stop $(docker ps -a -q)

# Remove all containers
docker rm $(docker ps -a -q)

# Remove all images related to the project
docker rmi $(docker images | grep 'avalanche\|microservices' | awk '{print $3}')

# Remove volumes
docker volume rm $(docker volume ls -q | grep 'microservices')

# Remove networks
docker network rm $(docker network ls | grep 'avalanche\|microservices' | awk '{print $1}')
```

For PowerShell:

```powershell
# Stop all containers
docker stop $(docker ps -a -q)

# Remove all containers
docker rm $(docker ps -a -q)

# Remove all images related to the project
docker images | Where-Object {$_.Contains('avalanche') -or $_.Contains('microservices')} | ForEach-Object { docker rmi $_.Split()[2] }

# Remove volumes
docker volume ls -q | Where-Object {$_.Contains('microservices')} | ForEach-Object { docker volume rm $_ }

# Remove networks
docker network ls | Where-Object {$_.Contains('avalanche') -or $_.Contains('microservices')} | ForEach-Object { docker network rm $_.Split()[0] }
``` 