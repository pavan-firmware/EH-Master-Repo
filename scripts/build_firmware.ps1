<#
.SYNOPSIS
  EH Home — Deterministic ESP-IDF Firmware Build Script (Multi-Target Aware)
.DESCRIPTION
  Builds the smart-switch-app using the pinned ESP-IDF 5.4.1 environment.
  Defaults to the production ESP32-C6 target (RISC-V). Also supports prototype ESP32 (Xtensa).
#>

param(
    [ValidateSet("esp32c6", "esp32", "esp32s3")]
    [string]$Target = "esp32c6",

    [ValidateSet("esp32c6-switch-platform", "esp32c6-socket-platform")]
    [string]$Family = "esp32c6-switch-platform",

    [ValidateSet("release", "debug")]
    [string]$Profile = "release",

    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$appDir = Join-Path $rootDir "firmware\platforms\esp32\smart-switch-app"

# 1. Activate Environment
. (Join-Path $scriptDir "activate_idf5.4.ps1")

# Set active target in environment
$env:IDF_TARGET = $Target

# 2. Verify Toolchain & Framework Invariants
$pythonExe = "$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe"
$idfPy = "$env:IDF_PATH\tools\idf.py"

$actualIdf = (& $pythonExe $idfPy --version 2>&1).Trim()
if ($actualIdf -notmatch "v5\.4\.1") {
    Write-Error "CRITICAL: Toolchain drift detected! Expected ESP-IDF v5.4.1, found: $actualIdf"
    exit 1
}

if ($Target -eq "esp32c6") {
    $gccVersion = (riscv32-esp-elf-gcc --version | Select-Object -First 1)
    $arch = "RISC-V 32-bit"
} else {
    $gccVersion = (xtensa-esp-elf-gcc --version | Select-Object -First 1)
    if (-not $gccVersion) {
        $gccVersion = (xtensa-esp32-elf-gcc --version | Select-Object -First 1)
    }
    $arch = "Xtensa 32-bit"
}

$pythonVer = (& $pythonExe --version)

Write-Host "`n>>> Pre-Build Verification:" -ForegroundColor Yellow
Write-Host "  ESP-IDF  : $actualIdf"
Write-Host "  Python   : $pythonVer"
Write-Host "  Family   : $Family"
Write-Host "  Target   : $Target ($arch)"
Write-Host "  Compiler : $gccVersion"
Write-Host "  Profile  : $Profile"
Write-Host "  App Dir  : $appDir`n"

# 3. Clean prior build if requested
$buildDir = Join-Path $appDir "build"
if ($Clean -and (Test-Path $buildDir)) {
    Write-Host ">>> Cleaning build directory: $buildDir" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $buildDir
}

# 4. Change to application directory and build
Set-Location $appDir

# If sdkconfig does not exist or target differs, set target
$sdkconfigPath = Join-Path $appDir "sdkconfig"
$needsSetTarget = $true
if (Test-Path $sdkconfigPath) {
    $sdkContent = Get-Content $sdkconfigPath -Raw
    if ($Target -eq "esp32c6" -and $sdkContent -match "CONFIG_IDF_TARGET_ESP32C6=y") {
        $needsSetTarget = $false
    } elseif ($Target -eq "esp32" -and $sdkContent -match "CONFIG_IDF_TARGET_ESP32=y") {
        $needsSetTarget = $false
    }
}

if ($needsSetTarget) {
    Write-Host ">>> Setting target to $Target..." -ForegroundColor Cyan
    & $pythonExe $idfPy set-target $Target
    if ($LASTEXITCODE -ne 0) {
        Write-Error "idf.py set-target $Target failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

# Bind environment variable for CMake configure & pass define
$env:EH_FIRMWARE_FAMILY = $Family

Write-Host ">>> Executing idf.py build for $Target ($Family)..." -ForegroundColor Cyan
& $pythonExe $idfPy -D EH_FIRMWARE_FAMILY=$Family build

if ($LASTEXITCODE -ne 0) {
    Write-Error "Firmware build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

# 5. Binary Artifact Verification & Embedded Family Content Check
$binaries = @(
    "bootloader\bootloader.bin",
    "partition_table\partition-table.bin",
    "eh-smart-switch-app.bin"
)

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "     FIRMWARE BUILD ARTIFACTS VERIFICATION ($Target - $Family)" -ForegroundColor Green
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

$appBinPath = Join-Path $buildDir "eh-smart-switch-app.bin"
if (Test-Path $appBinPath) {
    $rawBytes = [System.IO.File]::ReadAllBytes($appBinPath)
    $rawString = [System.Text.Encoding]::ASCII.GetString($rawBytes)
    $expectedMarker = "EH_FIRMWARE_FAMILY:$Family:END_FAMILY"
    if ($rawString.Contains($expectedMarker)) {
        Write-Host "`n  [PASS] Embedded Family Signature Verified: $expectedMarker" -ForegroundColor Green
    } else {
        Write-Error "CRITICAL: Compiled binary does NOT contain expected family marker: $expectedMarker"
        exit 1
    }
}
Write-Host "================================================================`n" -ForegroundColor Green
