@echo off
rem BlackBerry Bridge - BACKUP "from anywhere" path (plain HTTP, no certificate).
rem Use this ONLY if the normal remote (ENABLE-REMOTE) HTTPS address shows a security
rem warning on the BlackBerry. It opens the router port and prints a plain http:// URL.
rem Run START-BRIDGE first so the mirror is live.
title BlackBerry Bridge - Enable Failsafe (plain HTTP)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0host-setup\remote_failsafe.ps1"
echo.
pause
