@echo off
REM BlackBerry Bridge - one-click updater. Fully self-contained: even if this is the
REM ONLY file in the folder, it fetches the latest updater from GitHub and installs the
REM whole app over this folder. Your access code and settings are kept.
title BlackBerry Bridge - Update

REM this folder (with trailing backslash stripped) is what gets updated
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $u='https://raw.githubusercontent.com/OppaiMaster7/blackberry-bridge/master/host-setup/update.ps1'; $t=Join-Path $env:TEMP ('bb_update_'+[guid]::NewGuid().ToString('N')+'.ps1'); $ok=$false; if (Get-Command curl.exe -ErrorAction SilentlyContinue) { & curl.exe -sL --fail $u -o $t; if ((Test-Path $t) -and (Get-Item $t).Length -gt 500){$ok=$true} }; if (-not $ok) { try { (New-Object Net.WebClient).DownloadFile($u,$t); $ok=(Test-Path $t) } catch {} }; if (-not $ok) { Write-Host '[X] Could not reach GitHub. Check the internet connection.' -ForegroundColor Red; Read-Host 'Press Enter to close'; exit 1 }; & $t -Root '%ROOT%'"
