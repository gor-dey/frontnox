@echo off
setlocal

set "SILENT_FLAGS="
if /i "%~1"=="/S"    set "SILENT_FLAGS=-All -Lang en"
if /i "%~1"=="/S:en" set "SILENT_FLAGS=-All -Lang en"
if /i "%~1"=="/S:ru" set "SILENT_FLAGS=-All -Lang ru"

where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    pwsh -ExecutionPolicy Bypass -File "%~dp0scripts\Install.ps1" %SILENT_FLAGS%
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0scripts\Install.ps1" %SILENT_FLAGS%
)

endlocal & exit /b %errorlevel%
