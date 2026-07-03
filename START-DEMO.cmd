@echo off
rem BlackBerry Bridge - double-click before the demo. Brings up the Android source,
rem the BlackBerry simulator and the app, then prints a PASS/FAIL health check.
powershell -ExecutionPolicy Bypass -File "%~dp0host-setup\demo_up.ps1"
echo.
pause
