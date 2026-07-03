@echo off
REM ============================================================
REM  BlackBerry Bridge - double-click installer
REM  Self-elevates and runs the setup wizard (installs the
REM  Android emulator, droidVNC-NG, relay, and auto-start).
REM ============================================================
title BlackBerry Bridge Installer

REM --- relaunch elevated if not already admin ---
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Requesting administrator rights...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

echo.
echo  Installing BlackBerry Bridge (Android mirror source)...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_wizard.ps1"

echo.
echo  Done. Press any key to close.
pause >nul
