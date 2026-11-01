param(
    [string]$Port = "COM6"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   EH Home -- Instant Board QR Code Capture and Preview" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Target Port : $Port" -ForegroundColor Gray
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

$WorkspaceRoot = (Get-Item $PSScriptRoot).Parent.FullName
$ToolPath = Join-Path $WorkspaceRoot "tools\manufacturing\generate_dev_qr.py"
$pythonExe = if (Test-Path "$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe") {
    "$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe"
} else {
    "python"
}

& $pythonExe $ToolPath --port $Port --ascii --open
