@echo off
rem BlackBerry Bridge - turn on "use it from anywhere" (Tailscale Funnel).
rem Run this ONCE on the home laptop. A browser opens the first time to sign in
rem to a free Tailscale account. After that the BlackBerry works over any internet.
title BlackBerry Bridge - Enable Remote Access
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0host-setup\remote_access.ps1"
echo.
pause
