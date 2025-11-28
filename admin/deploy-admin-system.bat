@echo off
REM Admin System Deployment Batch Wrapper
REM Quick deployment of admin system

echo ========================================
echo   MySQL Admin System Deployment
echo ========================================
echo.

PowerShell.exe -ExecutionPolicy Bypass -File "%~dp0deploy-admin-system.ps1" %*

if %errorlevel% neq 0 (
    echo.
    echo Deployment failed!
    pause
    exit /b %errorlevel%
)

echo.
pause
