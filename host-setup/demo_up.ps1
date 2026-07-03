# demo_up.ps1 - BlackBerry Bridge: bring the WHOLE demo up with one command, then prove it.
#
# 1. Android content source (emulator + droidVNC + relay/keepalive/discovery supervisor)
# 2. BlackBerry 10 simulator VM (VMware)
# 3. BridgeLauncher app on the BlackBerry (terminate stale instance, launch fresh)
# 4. Health check: prints PASS/FAIL for every link in the chain
#
# Idempotent - run it as many times as you like, before every demo.
#
# Usage:  powershell -ExecutionPolicy Bypass -File demo_up.ps1

$ErrorActionPreference = "Continue"
$HERE  = Split-Path -Parent $MyInvocation.MyCommand.Path
$VMRUN = "C:\Program Files\VMware\VMware Workstation\vmrun.exe"
$VMX   = "C:\BB10Simulator\BlackBerry10Simulator.vmx"
$BBIP  = "192.168.94.128"
$JAVA  = "C:/bbndk/features/com.qnx.tools.jre.win32.x86_64_1.7.0.51/jre/bin/java.exe"
$BARJ  = "C:/bbndk/host_10_3_1_12/win32/x86/usr/lib/BarDeploy.jar"
$BAR   = Join-Path (Split-Path -Parent $HERE) "cascades-app\BridgeLauncher\BridgeLauncher.bar"
$ADB   = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "===== BlackBerry Bridge - demo bring-up =====" -ForegroundColor Cyan

# --- 1) Android source (idempotent; kills stale services itself) ---
& powershell -ExecutionPolicy Bypass -File "$HERE\start_android_source.ps1"

# --- 2) BlackBerry simulator VM ---
$running = (& $VMRUN list) -join "`n"
if ($running -notmatch [regex]::Escape($VMX)) {
  Write-Host "[*] starting BlackBerry simulator VM..."
  & $VMRUN -T ws start $VMX | Out-Null
} else { Write-Host "[=] BlackBerry simulator already running" }

Write-Host "[*] waiting for BlackBerry sim at $BBIP..."
$bbUp = $false
for ($i=0; $i -lt 60; $i++) {
  if (Test-Connection $BBIP -Count 1 -Quiet) { $bbUp = $true; break }
  Start-Sleep -Seconds 2
}
if ($bbUp) { Write-Host "[+] BlackBerry sim is up" }
else { Write-Host "[!] BlackBerry sim not answering ping - check the VMware window (it may need a keypress at the bootloader)" }

# --- 3) (re)launch the app on the BlackBerry ---
if ($bbUp -and (Test-Path $BAR)) {
  Write-Host "[*] relaunching BridgeLauncher on the BlackBerry..."
  & $JAVA "-Djava.awt.headless=true" -jar $BARJ -terminateApp -device $BBIP -package $BAR 2>&1 | Out-Null
  Start-Sleep -Seconds 1
  $launch = (& $JAVA "-Djava.awt.headless=true" -jar $BARJ -launchApp -device $BBIP -package $BAR 2>&1) -join "`n"
  if ($launch -match "result::(\d+|true|success|running)") { Write-Host "[+] app launched" }
  else { Write-Host "[!] app launch result unclear:`n$launch" }
}

# --- 4) health check ---
Write-Host ""
Write-Host "===== health check =====" -ForegroundColor Cyan
function Check($name, $ok) {
  if ($ok) { Write-Host ("  PASS  " + $name) -ForegroundColor Green }
  else     { Write-Host ("  FAIL  " + $name) -ForegroundColor Red }
  return $ok
}

$emu   = ((& $ADB shell getprop sys.boot_completed 2>$null) -replace '\s','') -eq "1"
$sq    = ((& $ADB shell wm size 2>$null) -join "`n") -match "720x720"
$fwd   = ((& $ADB forward --list) -join "`n") -match "tcp:5901"
$relay = (Test-NetConnection 127.0.0.1 -Port 5900 -InformationLevel Quiet -WarningAction SilentlyContinue)
$sup   = (Test-NetConnection 127.0.0.1 -Port 49321 -InformationLevel Quiet -WarningAction SilentlyContinue)
$agent = (Test-NetConnection 127.0.0.1 -Port 3389 -InformationLevel Quiet -WarningAction SilentlyContinue)
$vnc   = $false
$out = ((python "$HERE\vnc_probe.py" 2>$null) -join "`n"); if ($LASTEXITCODE -eq 0) { $vnc = $true }
$gw = $false
$gwKey = (Get-Content "$HERE\bridge_access_key.txt" -ErrorAction SilentlyContinue | Select-Object -First 1)
try { $g = Invoke-WebRequest -Uri "http://127.0.0.1:8080/status?k=$gwKey" -UseBasicParsing -TimeoutSec 6; $gw = ($g.Content -match '"connected": true') } catch {}

$all = $true
$all = (Check "Android emulator booted"                    $emu)   -and $all
$all = (Check "Android screen is 720x720"                  $sq)    -and $all
$all = (Check "adb forward 5901 -> droidVNC"               $fwd)   -and $all
$all = (Check "droidVNC serving frames (via relay path)"   $vnc)   -and $all
$all = (Check "relay listening on 5900"                    $relay) -and $all
$all = (Check "supervisor alive (lock port)"               $sup)   -and $all
$all = (Check "discovery agent (TCP 3389)"                 $agent) -and $all
$all = (Check "browser gateway for the phone (8080)"       $gw)    -and $all
$all = (Check "BlackBerry sim reachable ($BBIP)"           $bbUp)  -and $all

Write-Host ""
if ($all) {
  Write-Host "ALL SYSTEMS GO - the BlackBerry links and mirrors by itself." -ForegroundColor Green
} else {
  Write-Host "Something above FAILED - re-run this script; if it persists, check that stage's log." -ForegroundColor Yellow
}
