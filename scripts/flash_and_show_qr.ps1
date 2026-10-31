param(
    [string]$Port = "COM6",
    [switch]$EraseFirst = $false
)

$ErrorActionPreference = "Stop"
$WorkspaceRoot = (Get-Item $PSScriptRoot).Parent.FullName
$AppDir = Join-Path $WorkspaceRoot "firmware\platforms\esp32\smart-switch-app"
$ToolPath = Join-Path $WorkspaceRoot "tools\manufacturing\generate_dev_qr.py"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   EH Home -- Flash and Auto-Show QR Code Pipeline" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Target Port : $Port" -ForegroundColor Gray
Write-Host "  Erase Flash : $EraseFirst" -ForegroundColor Gray
Write-Host "  App Dir     : $AppDir" -ForegroundColor Gray
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Ensure ESP-IDF environment is active
if (-not (Get-Command idf.py -ErrorAction SilentlyContinue) -or -not $env:IDF_PATH) {
    $activateScript = Join-Path $PSScriptRoot "activate_idf5.4.ps1"
    if (Test-Path $activateScript) {
        . $activateScript
    }
}

$pythonExe = if (Test-Path "$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe") {
    "$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe"
} else {
    "python"
}
$idfPy = "$env:IDF_PATH\tools\idf.py"

# Step 1: Flash Firmware
Push-Location $AppDir
try {
    if ($EraseFirst) {
        Write-Host ">>> Erasing flash and flashing firmware..." -ForegroundColor Yellow
        & $pythonExe $idfPy -p $Port erase-flash flash
    } else {
        Write-Host ">>> Flashing firmware to $Port..." -ForegroundColor Yellow
        & $pythonExe $idfPy -p $Port flash
    }
    if ($LASTEXITCODE -ne 0) {
        throw "idf.py flash failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

# Step 2: Automatically Capture and Display QR Code
Write-Host ""
Write-Host ">>> Flashing complete! Capturing device QR code..." -ForegroundColor Green
Start-Sleep -Milliseconds 500
& $pythonExe $ToolPath --port $Port --ascii --open
