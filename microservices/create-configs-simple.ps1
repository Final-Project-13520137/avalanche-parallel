# Script PowerShell sederhana untuk membuat konfigurasi monitoring

Write-Host "Membuat direktori monitoring..." -ForegroundColor Green

# Buat direktori
$dirs = "monitoring\loki", "monitoring\promtail", "monitoring\otel", "monitoring\nginx"
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Host "Created: $dir" -ForegroundColor Yellow
}

# File loki config basic
@"
auth_enabled: false
server:
  http_listen_port: 3100
ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h
storage_config:
  boltdb:
    directory: /tmp/loki/index
  filesystem:
    directory: /tmp/loki/chunks
"@ | Out-File -FilePath "monitoring\loki\loki-config.yml" -Encoding UTF8

Write-Host "Created: loki-config.yml" -ForegroundColor Yellow

# File promtail config basic  
@"
server:
  http_listen_port: 9080
positions:
  filename: /tmp/positions.yaml
clients:
  - url: http://loki:3100/loki/api/v1/push
scrape_configs:
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
"@ | Out-File -FilePath "monitoring\promtail\promtail-config.yml" -Encoding UTF8

Write-Host "Created: promtail-config.yml" -ForegroundColor Yellow

# File OTEL config basic
@"
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
processors:
  batch:
exporters:
  prometheus:
    endpoint: 0.0.0.0:8888
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
"@ | Out-File -FilePath "monitoring\otel\otel-collector-config.yml" -Encoding UTF8

Write-Host "Created: otel-collector-config.yml" -ForegroundColor Yellow
Write-Host "All config files created successfully!" -ForegroundColor Green 