<#
.SYNOPSIS
  EH Home — ESP-IDF 5.4.1 Environment Activation Script
.DESCRIPTION
  Deterministically sets IDF_PATH, Python virtual environment, toolchain paths,
  and environment variables for building the EH Home ESP32 firmware line.
#>

$ErrorActionPreference = "Stop"

$IDF_PATH = "C:\esp\v5.4.1\esp-idf"
$IDF_PYTHON_ENV_PATH = "C:\Users\pavan\.espressif\python_env\idf5.4_py3.14_env"
$IDF_TOOLS_PATH = "C:\Users\pavan\.espressif"

if (-not (Test-Path $IDF_PATH)) {
    Write-Error "ESP-IDF v5.4.1 framework not found at $IDF_PATH. Check installation."
    exit 1
}

if (-not (Test-Path "$IDF_PYTHON_ENV_PATH\Scripts\python.exe")) {
    Write-Error "Python 3.14 environment not found at $IDF_PYTHON_ENV_PATH. Check installation."
    exit 1
}

$env:IDF_PATH = $IDF_PATH
$env:IDF_PYTHON_ENV_PATH = $IDF_PYTHON_ENV_PATH
$env:IDF_TOOLS_PATH = $IDF_TOOLS_PATH
$env:ESP_ROM_ELF_DIR = "C:\Users\pavan\.espressif\tools\esp-rom-elfs\20241011\"
$env:OPENOCD_SCRIPTS = "C:\Users\pavan\.espressif\tools\openocd-esp32\v0.12.0-esp32-20241016\openocd-esp32\share\openocd\scripts"
$env:IDF_CCACHE_ENABLE = "1"
$env:IDF_TARGET = "esp32"

$toolPaths = @(
    "C:\Users\pavan\.espressif\tools\xtensa-esp-elf-gdb\14.2_20240403\xtensa-esp-elf-gdb\bin",
    "C:\Users\pavan\.espressif\tools\riscv32-esp-elf-gdb\14.2_20240403\riscv32-esp-elf-gdb\bin",
    "C:\Users\pavan\.espressif\tools\xtensa-esp-elf\esp-14.2.0_20241119\xtensa-esp-elf\bin",
    "C:\Users\pavan\.espressif\tools\riscv32-esp-elf\esp-14.2.0_20241119\riscv32-esp-elf\bin",
    "C:\Users\pavan\.espressif\tools\esp32ulp-elf\2.38_20240113\esp32ulp-elf\bin",
    "C:\Users\pavan\.espressif\tools\cmake\3.30.2\bin",
    "C:\Users\pavan\.espressif\tools\openocd-esp32\v0.12.0-esp32-20241016\openocd-esp32\bin",
    "C:\Users\pavan\.espressif\tools\ninja\1.12.1",
    "C:\Users\pavan\.espressif\tools\idf-exe\1.0.3",
    "C:\Users\pavan\.espressif\tools\ccache\4.10.2\ccache-4.10.2-windows-x86_64",
    "$IDF_PYTHON_ENV_PATH\Scripts",
    "$IDF_PATH\tools"
)

$env:PATH = ($toolPaths -join ";") + ";" + $env:PATH

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   EH Home ESP-IDF 5.4.1 Build Environment Activated" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  IDF_PATH            : $env:IDF_PATH"
Write-Host "  Python Venv         : $env:IDF_PYTHON_ENV_PATH"
Write-Host "  Target              : $env:IDF_TARGET"
$idfVersion = & "$IDF_PYTHON_ENV_PATH\Scripts\python.exe" "$IDF_PATH\tools\idf.py" --version
Write-Host "  Framework Version   : $idfVersion"
Write-Host "================================================================" -ForegroundColor Cyan
