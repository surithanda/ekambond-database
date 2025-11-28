@echo off
REM Batch wrapper for deploy-prod-database.ps1
REM This makes it easier to run the PowerShell script

echo.
echo =============================================
echo  MySQL Production Database Deployment
echo  Database: matrimony_services
echo =============================================
echo.

REM Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: PowerShell not found in PATH
    echo Please ensure PowerShell is installed
    pause
    exit /b 1
)

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Run the PowerShell script with parameters passed through
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_DIR%deploy-prod-database.ps1" %*

REM Pause to see results
echo.
pause
