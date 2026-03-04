# start_backend.ps1
# Starts the Django development server on all interfaces (port 8000)
# Run this script from the VTU directory:  .\start_backend.ps1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$djangoDir = Join-Path $scriptDir "vtu"
$python    = Join-Path $djangoDir "env\Scripts\python.exe"
$manage    = Join-Path $djangoDir "manage.py"

if (-not (Test-Path $python)) {
    Write-Error "Python not found at: $python`nMake sure the virtual environment is set up in vtu\env"
    exit 1
}

Write-Host "▶  Starting Django server on http://localhost:8000" -ForegroundColor Green
Write-Host "   Stop with Ctrl+C`n" -ForegroundColor Gray

# Optional: set your Paystack test key here
# $env:PAYSTACK_SECRET_KEY = "sk_test_xxxxxxxxxxxxxxxx"

& $python $manage runserver 0.0.0.0:8000
