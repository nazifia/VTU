# start_flutter.ps1
# Starts the Flutter app.
# - Runs as a WINDOWS DESKTOP app by default (fastest — no emulator needed)
# - To run on Android emulator instead, uncomment the last line and comment out the Windows line
#
# Usage:  .\start_flutter.ps1

$ErrorActionPreference = "Stop"
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterDir = Join-Path $scriptDir "vtu_app"

Write-Host "▶  Starting Flutter (Windows desktop)" -ForegroundColor Cyan
Write-Host "   API → http://localhost:8000/api/v1`n" -ForegroundColor Gray

Set-Location $flutterDir

# Windows desktop (default — no emulator needed)
flutter run -d windows

# Android emulator (uncomment to use instead)
# flutter run -d emulator-5554
