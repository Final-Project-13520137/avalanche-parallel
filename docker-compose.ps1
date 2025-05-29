#!/usr/bin/env pwsh
# docker-compose.ps1
# Helper script to use docker-compose with the configuration file in the config directory

Write-Host "Using docker-compose.yml from config directory" -ForegroundColor Cyan

# Forward all arguments to docker-compose with the -f flag pointing to the config file
docker-compose -f config/docker-compose.yml $args 