# Script PowerShell untuk membuat file konfigurasi monitoring yang hilang

Write-Host "🔧 Membuat file konfigurasi monitoring..." -ForegroundColor Cyan

# Buat direktori yang diperlukan
$directories = @(
    "monitoring\loki",
    "monitoring\promtail", 
    "monitoring\otel",
    "monitoring\nginx",
    "monitoring\nginx\ssl"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "✓ Direktori $dir dibuat" -ForegroundColor Green
    }
}

# Buat loki-config.yml
$lokiConfig = @"
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 1h
  max_chunk_age: 1h
  chunk_target_size: 1048576
  chunk_retain_period: 30s
  max_transfer_retries: 0

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
"@

$lokiConfig | Out-File -FilePath "monitoring\loki\loki-config.yml" -Encoding UTF8
Write-Host "✓ File loki-config.yml dibuat" -ForegroundColor Green

# Buat promtail-config.yml
$promtailConfig = @"
server:
  http_listen_port: 9080
  grpc_listen_port: 0

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
          __path__: /var/lib/docker/containers/*/*log

    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag:
          source: attrs
      - regex:
          expression: (?P<container_name>(?:[^|]*))\|
          source: tag
      - timestamp:
          format: RFC3339Nano
          source: time
      - labels:
          stream:
          container_name:
      - output:
          source: output
"@

$promtailConfig | Out-File -FilePath "monitoring\promtail\promtail-config.yml" -Encoding UTF8
Write-Host "✓ File promtail-config.yml dibuat" -ForegroundColor Green

# Buat otel-collector-config.yml
$otelConfig = @"
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
    endpoint: "0.0.0.0:8888"
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
"@

$otelConfig | Out-File -FilePath "monitoring\otel\otel-collector-config.yml" -Encoding UTF8
Write-Host "✓ File otel-collector-config.yml dibuat" -ForegroundColor Green

Write-Host "🎉 Semua file konfigurasi monitoring berhasil dibuat!" -ForegroundColor Green
Write-Host ""
Write-Host "Sekarang coba jalankan: docker-compose -f docker-compose.monitoring.yml up -d" -ForegroundColor Yellow 