@echo off
rem BlackBerry Bridge - daily start. Double-click me, wait for [DONE], then open the
rem printed address in the BlackBerry's browser. (One-time setup first: run
rem host-setup\Install-BlackBerryBridge.cmd; for use-from-anywhere run ENABLE-REMOTE.cmd)
title BlackBerry Bridge
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "& '%~dp0host-setup\start_android_source.ps1';" ^
  "$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and $_.InterfaceAlias -notmatch 'vEthernet|VMware|Loopback|WSL' } | Select-Object -First 1).IPAddress;" ^
  "$kf = '%~dp0host-setup\bridge_access_key.txt'; $k = $null;" ^
  "for ($i=0; $i -lt 20 -and -not $k; $i++) { $k = (Get-Content $kf -ErrorAction SilentlyContinue | Select-Object -First 1); if (-not $k) { Start-Sleep -Milliseconds 500 } };" ^
  "$pub = (Get-Content '%~dp0host-setup\bridge_public_url.txt' -ErrorAction SilentlyContinue | Select-Object -First 1);" ^
  "Write-Host '';" ^
  "Write-Host '=============================================================' -ForegroundColor Green;" ^
  "Write-Host '  ON THE BLACKBERRY BROWSER, OPEN:' -ForegroundColor Green;" ^
  "Write-Host ('   Same Wi-Fi:  http://' + $ip + ':8080/?k=' + $k) -ForegroundColor Green;" ^
  "if ($pub) { Write-Host ('   Anywhere:   ' + $pub + '/?k=' + $k) -ForegroundColor Cyan };" ^
  "Write-Host '  (the ?k= part is the access code - keep it secret)' -ForegroundColor Green;" ^
  "Write-Host '=============================================================' -ForegroundColor Green"
echo.
pause
