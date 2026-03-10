@echo off
setlocal enabledelayedexpansion
title Npay Launcher

echo ==========================================
echo   Npay  -  Backend + Emulator Launcher
echo ==========================================
echo.

REM ── Step 1: Start Django backend in a new window ──────────────────────────
echo [1/3] Starting Django backend...
start "Npay Backend" cmd /k "cd /d %~dp0vtu && (if exist env\Scripts\python.exe (env\Scripts\python.exe manage.py runserver 0.0.0.0:8000) else (python manage.py runserver 0.0.0.0:8000))"

REM ── Step 2: Health-check loop — wait until Django is actually ready ────────
echo [2/3] Waiting for backend to be ready...
set /a attempts=0
:health_check
set /a attempts+=1
if %attempts% gtr 30 (
    echo.
    echo ERROR: Backend did not start after 60 seconds. Check the Backend window.
    pause
    exit /b 1
)
timeout /t 2 /nobreak >nul
curl -s --max-time 2 http://localhost:8000/api/v1/auth/send-otp/ >nul 2>&1
if errorlevel 1 (
    echo    Attempt %attempts%/30 - still starting...
    goto health_check
)
echo    Backend is ready on http://localhost:8000

REM ── Step 3: Detect emulator and launch Flutter ────────────────────────────
echo.
echo [3/3] Detecting Android emulator...
set EMULATOR_ID=
for /f "tokens=*" %%L in ('flutter devices 2^>nul') do (
    echo %%L | findstr /i "emulator" >nul 2>&1
    if not errorlevel 1 (
        for /f "tokens=1" %%D in ("%%L") do (
            if not defined EMULATOR_ID set EMULATOR_ID=%%D
        )
    )
)

if not defined EMULATOR_ID (
    echo    No running emulator found. Launching on auto-detected device...
    set FLUTTER_DEVICE_FLAG=
) else (
    echo    Found: %EMULATOR_ID%
    set FLUTTER_DEVICE_FLAG=-d %EMULATOR_ID%
)

echo    Starting Flutter app...
start "Npay App" cmd /k "cd /d %~dp0vtu_app && flutter run %FLUTTER_DEVICE_FLAG%"

echo.
echo ==========================================
echo   All services launched!
echo.
echo   Backend:  http://localhost:8000/api/v1/
echo   Admin:    http://localhost:8000/admin/
echo   Emulator: %EMULATOR_ID%
echo ==========================================
timeout /t 5
