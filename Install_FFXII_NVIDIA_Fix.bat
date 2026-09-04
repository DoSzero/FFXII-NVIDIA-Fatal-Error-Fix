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

rem The PS1 self-elevates and pauses in its own window, so suppress the pause here.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install_FFXII_NVIDIA_Fix.ps1" -NoPause %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo [ERROR] Installer exited with code %RC%.
    echo.
    pause
)

exit /b %RC%
