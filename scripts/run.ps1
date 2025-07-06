#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("deployment", "setup", "benchmark", "maintenance", "scaling", "testing", "utility", "help")]
    [string]$Category,
    
    [Parameter(Mandatory=$false)]
    [string]$Script,
    
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

Write-Host "🚀 Avalanche Parallel DAG Script Runner" -ForegroundColor Yellow
Write-Host "====================================" -ForegroundColor Yellow

function Show-Help {
    Write-Host "📋 Kategori Script yang Tersedia:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📦 deployment  - Script untuk deployment dan restart" -ForegroundColor Green
    Write-Host "⚙️ setup       - Script untuk setup dan konfigurasi" -ForegroundColor Green
    Write-Host "📊 benchmark   - Script untuk benchmark dan testing performa" -ForegroundColor Green
    Write-Host "🧹 maintenance - Script untuk pembersihan dan maintenance" -ForegroundColor Green
    Write-Host "📈 scaling     - Script untuk scaling dan node management" -ForegroundColor Green
    Write-Host "🧪 testing     - Script untuk testing dan validasi" -ForegroundColor Green
    Write-Host "🔧 utility     - Script utility dan helper" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 Contoh penggunaan:" -ForegroundColor Yellow
    Write-Host "   .\scripts\run.ps1 deployment" -ForegroundColor White
    Write-Host "   .\scripts\run.ps1 deployment deploy-docker.ps1 --build --workers 3" -ForegroundColor White
    Write-Host "   .\scripts\run.ps1 benchmark run_parallel_benchmark.ps1 -FullTest" -ForegroundColor White
    Write-Host "   .\scripts\run.ps1 maintenance cleanup-all.ps1" -ForegroundColor White
}

function Show-Scripts {
    param($CategoryPath)
    
    if (!(Test-Path $CategoryPath)) {
        Write-Host "❌ Kategori tidak ditemukan: $CategoryPath" -ForegroundColor Red
        return
    }
    
    $scripts = Get-ChildItem -Path $CategoryPath -File | Sort-Object Name
    
    if ($scripts.Count -eq 0) {
        Write-Host "ℹ️ Tidak ada script dalam kategori ini" -ForegroundColor Yellow
        return
    }
    
    Write-Host "📜 Script yang tersedia dalam kategori '$Category':" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($script in $scripts) {
        $icon = switch ($script.Extension) {
            ".ps1" { "🟦" }
            ".sh" { "🟩" }
            ".go" { "🔷" }
            ".bat" { "🟨" }
            default { "📄" }
        }
        Write-Host "   $icon $($script.Name)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "💡 Untuk menjalankan script:" -ForegroundColor Yellow
    Write-Host "   .\scripts\run.ps1 $Category <nama-script> [arguments]" -ForegroundColor White
}

function Run-Script {
    param($CategoryPath, $ScriptName, $Args)
    
    $scriptPath = Join-Path $CategoryPath $ScriptName
    
    if (!(Test-Path $scriptPath)) {
        Write-Host "❌ Script tidak ditemukan: $scriptPath" -ForegroundColor Red
        Write-Host ""
        Show-Scripts $CategoryPath
        return
    }
    
    Write-Host "🚀 Menjalankan: $scriptPath" -ForegroundColor Green
    if ($Args) {
        Write-Host "📝 Arguments: $($Args -join ' ')" -ForegroundColor Cyan
    }
    Write-Host ""
    
    $extension = [System.IO.Path]::GetExtension($ScriptName)
    
    switch ($extension) {
        ".ps1" {
            if ($Args) {
                & $scriptPath @Args
            } else {
                & $scriptPath
            }
        }
        ".sh" {
            if ($Args) {
                bash $scriptPath @Args
            } else {
                bash $scriptPath
            }
        }
        ".go" {
            if ($Args) {
                go run $scriptPath @Args
            } else {
                go run $scriptPath
            }
        }
        ".bat" {
            if ($Args) {
                cmd /c "$scriptPath $($Args -join ' ')"
            } else {
                cmd /c $scriptPath
            }
        }
        default {
            Write-Host "⚠️ Tidak tahu cara menjalankan file dengan ekstensi: $extension" -ForegroundColor Yellow
        }
    }
}

# Main logic
if ($Category -eq "help") {
    Show-Help
    return
}

$categoryPath = Join-Path "scripts" $Category

if ([string]::IsNullOrEmpty($Script)) {
    Show-Scripts $categoryPath
} else {
    Run-Script $categoryPath $Script $Arguments
} 