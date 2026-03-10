@echo off
REM ── Npay Django Backend ────────────────────────────────────────────────────
REM This script is called by Android Studio before launching the Flutter app.
cd /d "%~dp0vtu"
if exist env\Scripts\python.exe (
    env\Scripts\python.exe manage.py runserver 0.0.0.0:8000
) else (
    python manage.py runserver 0.0.0.0:8000
)
