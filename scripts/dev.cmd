@echo off
setlocal
chcp 65001 >nul
if "%~1"=="" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev-menu.ps1"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev.ps1" %*
)
if errorlevel 1 (
  echo.
  echo Idea2Strategy development environment command failed.
  pause
  exit /b 1
)
