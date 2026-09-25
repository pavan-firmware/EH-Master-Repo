<#
.SYNOPSIS
  EH Home — Deterministic ESP32 Firmware Build Script
.DESCRIPTION
  Builds the smart-switch-app using the pinned ESP-IDF 5.4.1 environment.
#>

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$appDir = Join-Path $rootDir "firmware\platforms\esp32\smart-switch-app"

# 1. Activate Environment
. (Join-Path $scriptDir "activate_idf5.4.ps1")

# 2. Verify Toolchain & Framework Invariants
$pythonExe = "$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe"
$idfPy = "$env:IDF_PATH\tools\idf.py"

$actualIdf = (& $pythonExe $idfPy --version 2>&1).Trim()
if ($actualIdf -notmatch "v5\.4\.1") {
    Write-Error "CRITICAL: Toolchain drift detected! Expected ESP-IDF v5.4.1, found: $actualIdf"
    exit 1
}

$gccVersion = (xtensa-esp32-elf-gcc --version | Select-Object -First 1)
$pythonVer = (& $pythonExe --version)

Write-Host "`n>>> Pre-Build Verification:" -ForegroundColor Yellow
Write-Host "  ESP-IDF  : $actualIdf"
Write-Host "  Python   : $pythonVer"
Write-Host "  Compiler : $gccVersion"
Write-Host "  Target   : esp32"
Write-Host "  App Dir  : $appDir`n"

# 3. Change to application directory and build
Set-Location $appDir

Write-Host ">>> Executing idf.py build..." -ForegroundColor Cyan
& $pythonExe $idfPy build

if ($LASTEXITCODE -ne 0) {
    Write-Error "Firmware build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

# 4. Binary Artifact Verification
$buildDir = Join-Path $appDir "build"
$binaries = @(
    "bootloader\bootloader.bin",
    "partition_table\partition-table.bin",
    "eh-smart-switch-app.bin"
)

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "           FIRMWARE BUILD ARTIFACTS VERIFICATION" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green

foreach ($relBin in $binaries) {
    $fullBin = Join-Path $buildDir $relBin
    if (Test-Path $fullBin) {
        $item = Get-Item $fullBin
        $hash = (Get-FileHash -Path $fullBin -Algorithm SHA256).Hash
        Write-Host ("  {0,-36} | {1,8} bytes | SHA256: {2}" -f $relBin, $item.Length, $hash)
    } else {
        Write-Host "  MISSING: $relBin" -ForegroundColor Red
    }
}
Write-Host "================================================================`n" -ForegroundColor Green
