@echo off
where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    pwsh -ExecutionPolicy Bypass -File "%~dp0scripts\Uninstall.ps1"
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0scripts\Uninstall.ps1"
)
