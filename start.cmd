@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1"
if errorlevel 1 (
    echo.
    echo LivChart setup failed.
    pause
    exit /b 1
)

endlocal
