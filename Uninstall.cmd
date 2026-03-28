@echo off
setlocal

set "SILENT_FLAGS="
if /i "%~1"=="/S" set "SILENT_FLAGS=-Silent"

where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    pwsh -ExecutionPolicy Bypass -File "%~dp0scripts\Uninstall.ps1" %SILENT_FLAGS%
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0scripts\Uninstall.ps1" %SILENT_FLAGS%
)

endlocal & exit /b %errorlevel%
