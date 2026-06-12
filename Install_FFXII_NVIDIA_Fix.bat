@echo off
setlocal
title FFXII NVIDIA Fix Installer

cd /d "%~dp0"

if not exist "Install_FFXII_NVIDIA_Fix.ps1" (
    echo [ERROR] Install_FFXII_NVIDIA_Fix.ps1 not found in this folder.
    echo Please extract the full archive first and run this BAT from the extracted folder.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install_FFXII_NVIDIA_Fix.ps1"

echo.
pause
