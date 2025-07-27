# Script PowerShell untuk mengunduh kubectl binary
# Script ini mengunduh kubectl untuk menghindari file besar di git repository

param(
    [string]$Version = "v1.28.2",
    [string]$InstallPath = "."
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "🔽 Downloading kubectl ${Version} for Windows..." "Cyan"

# Determine architecture
$arch = "amd64"
if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
    $arch = "arm64"
}

$kubectlUrl = "https://dl.k8s.io/release/${Version}/bin/windows/${arch}/kubectl.exe"
$kubectlPath = Join-Path $InstallPath "kubectl.exe"

Write-ColorOutput "URL: $kubectlUrl" "Yellow"
Write-ColorOutput "Destination: $kubectlPath" "Yellow"

try {
    # Download kubectl
    Write-ColorOutput "⏳ Downloading..." "Yellow"
    Invoke-WebRequest -Uri $kubectlUrl -OutFile $kubectlPath
    
    Write-ColorOutput "✅ kubectl.exe downloaded successfully!" "Green"
    
    # Verify the download
    Write-ColorOutput "🔍 Verifying kubectl..." "Cyan"
    & $kubectlPath version --client
    
    Write-ColorOutput "✅ kubectl is ready to use!" "Green"
    Write-ColorOutput "💡 You can move it to your PATH or use it from: $kubectlPath" "Blue"
    
} catch {
    Write-ColorOutput "❌ Error downloading kubectl: $($_.Exception.Message)" "Red"
    exit 1
} 