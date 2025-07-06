# Avalanche Microservices Startup Script
# Menjalankan semua komponen microservices secara bertahap

Write-Host "🚀 Memulai Avalanche Microservices..." -ForegroundColor Green
Write-Host "=" * 50

# Step 1: Clean up existing containers
Write-Host "🧹 Membersihkan container yang ada..." -ForegroundColor Yellow
docker-compose -f docker-compose.simple.yml down --volumes 2>$null

# Step 2: Start infrastructure
Write-Host "🔧 Memulai infrastruktur (Redis dan PostgreSQL)..." -ForegroundColor Yellow
docker-compose -f docker-compose.simple.yml up -d redis postgres

# Wait for infrastructure to be ready
Write-Host "⏳ Menunggu infrastruktur siap..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Check infrastructure status
Write-Host "📊 Status infrastruktur:" -ForegroundColor Cyan
docker-compose -f docker-compose.simple.yml ps

# Step 3: Test Redis connection
Write-Host "🔍 Testing Redis connection..." -ForegroundColor Yellow
$redisTest = docker exec avalanche-redis redis-cli ping 2>$null
if ($redisTest -eq "PONG") {
    Write-Host "✅ Redis: Connected" -ForegroundColor Green
} else {
    Write-Host "❌ Redis: Failed to connect" -ForegroundColor Red
}

# Step 4: Test PostgreSQL connection
Write-Host "🔍 Testing PostgreSQL connection..." -ForegroundColor Yellow
$pgTest = docker exec avalanche-postgres pg_isready -U avalanche 2>$null
if ($pgTest -match "accepting connections") {
    Write-Host "✅ PostgreSQL: Connected" -ForegroundColor Green
} else {
    Write-Host "❌ PostgreSQL: Failed to connect" -ForegroundColor Red
}

# Step 5: Start monitoring
Write-Host "📈 Memulai monitoring (Prometheus dan Grafana)..." -ForegroundColor Yellow
docker-compose -f docker-compose.simple.yml up -d prometheus grafana

Write-Host "⏳ Menunggu monitoring services..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Step 6: Build and start workers (if build succeeds)
Write-Host "🏗️ Membangun dan menjalankan workers..." -ForegroundColor Yellow
Write-Host "   Ini mungkin memakan waktu beberapa menit..." -ForegroundColor Gray

try {
    # Build API Gateway first
    docker-compose -f docker-compose.simple.yml build api-gateway
    docker-compose -f docker-compose.simple.yml up -d api-gateway
    
    Write-Host "✅ API Gateway: Built and started" -ForegroundColor Green
    
    # Build and start workers one by one
    docker-compose -f docker-compose.simple.yml build consensus-worker
    docker-compose -f docker-compose.simple.yml up -d consensus-worker
    Write-Host "✅ Consensus Worker: Built and started" -ForegroundColor Green
    
    docker-compose -f docker-compose.simple.yml build validator-worker
    docker-compose -f docker-compose.simple.yml up -d validator-worker
    Write-Host "✅ Validator Worker: Built and started" -ForegroundColor Green
    
    docker-compose -f docker-compose.simple.yml build dag-state-worker
    docker-compose -f docker-compose.simple.yml up -d dag-state-worker
    Write-Host "✅ DAG/State Worker: Built and started" -ForegroundColor Green
    
} catch {
    Write-Host "⚠️ Some workers failed to build. Continuing with available services..." -ForegroundColor Yellow
}

# Step 7: Final status check
Write-Host ""
Write-Host "🏁 Status Final:" -ForegroundColor Green
Write-Host "=" * 50

docker-compose -f docker-compose.simple.yml ps

Write-Host ""
Write-Host "🌐 Akses Services:" -ForegroundColor Cyan
Write-Host "• API Gateway: http://localhost:9750/health" -ForegroundColor White
Write-Host "• Redis: localhost:6379" -ForegroundColor White
Write-Host "• PostgreSQL: localhost:5432 (user: avalanche, pass: avalanche123)" -ForegroundColor White
Write-Host "• Prometheus: http://localhost:9090" -ForegroundColor White
Write-Host "• Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor White
Write-Host "• Consensus Worker: http://localhost:8080/health" -ForegroundColor White
Write-Host "• Validator Worker: http://localhost:8081/health" -ForegroundColor White
Write-Host "• DAG/State Worker: http://localhost:8082/health" -ForegroundColor White

Write-Host ""
Write-Host "✨ Avalanche Microservices siap digunakan!" -ForegroundColor Green
Write-Host "📝 Lihat logs dengan: docker-compose -f docker-compose.simple.yml logs -f [service-name]" -ForegroundColor Gray 