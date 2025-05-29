# Simple PowerShell script to downgrade multierr

Write-Host "Fixing multierr dependency for Go 1.18 compatibility..."

# Backup original go.mod
Copy-Item -Path "go.mod" -Destination "go.mod.bak" -Force

# Read the linux version and use it as reference
$linuxGoMod = Get-Content -Path "go.mod.linux" -Raw

# Update the go.mod file
$linuxGoMod | Set-Content -Path "go.mod" -Force

# Run go mod tidy
go mod tidy

Write-Host "Fix completed. Try running your tests now." 