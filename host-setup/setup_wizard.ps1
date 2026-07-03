# =====================================================================================
#  BlackBerry Bridge — Host Setup Wizard
#  Run ONCE on the "mirroring laptop" (double-click Install-BlackBerryBridge.cmd).
#  Installs & configures EVERYTHING the bridge needs on a fresh Windows machine:
#    Python (+Pillow), a portable JDK, the Android emulator + Play-Store image,
#    droidVNC-NG, firewall rule for the phone, auto-start, desktop shortcut.
#  Idempotent: safe to re-run. Needs internet (one-time downloads, ~2 GB total).
#
#  After setup the daily flow is: double-click "START-BRIDGE" on the Desktop, then on
#  the BlackBerry open the browser at the address it prints. That's it.
# =====================================================================================
$ErrorActionPreference = "Stop"
$HERE   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT   = Split-Path -Parent $HERE
$SDK    = "$env:LOCALAPPDATA\Android\Sdk"
$AVD    = "BridgePhone"
$IMAGE  = "system-images;android-34;google_apis_playstore;x86_64"
$APK    = Join-Path $HERE "droidvnc-ng-2.20.0.apk"
$PKG    = "net.christianbeier.droidvnc_ng"

function Step($n,$msg){ Write-Host ""; Write-Host "== [$n] $msg" -ForegroundColor Cyan }
function Ok($m){ Write-Host "   [+] $m" -ForegroundColor Green }
function Info($m){ Write-Host "   [*] $m" }

# --- 0) Python (runs the bridge services) --------------------------------------------
Step 0 "Python"
function Test-Python($exe) {
  try { $v = & $exe -c "import sys; print(sys.version_info[0], sys.version_info[1])" 2>$null
        if ($v -match "^3 (\d+)" -and [int]$Matches[1] -ge 8) { return $true } } catch {}
  return $false
}
$PY = $null
foreach ($cand in @("python", "py")) {
  if (Test-Python $cand) { $PY = $cand; break }
}
if (-not $PY) {
  Info "Python not found - downloading (one-time, ~27 MB)..."
  $pyExe = "$env:TEMP\python-installer.exe"
  Invoke-WebRequest "https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe" -OutFile $pyExe
  Info "installing Python silently..."
  Start-Process $pyExe -ArgumentList "/quiet","InstallAllUsers=1","PrependPath=1","Include_test=0" -Wait
  $env:PATH = [Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH","User")
  if (-not (Test-Python "python")) { throw "Python install failed - install it manually from python.org, then re-run." }
  $PY = "python"
}
& $PY -m pip install --quiet pillow
Ok "Python ready (with Pillow)"

# --- 1) Java (needed by Android's sdkmanager; portable, no system install) ----------
Step 1 "Java for the Android SDK tools"
$jdk = $null
foreach ($c in @("$env:JAVA_HOME\bin\java.exe",
                 "C:\Program Files\Android\Android Studio\jbr\bin\java.exe",
                 "C:\Program Files\Microsoft\jdk-17*\bin\java.exe",
                 "C:\Program Files\Eclipse Adoptium\jdk-17*\bin\java.exe",
                 "$HERE\jdk\*\bin\java.exe")) {
  $r = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($r) { $jdk = $r.FullName; break }
}
if (-not $jdk) {
  Info "no JDK found - downloading a portable one (one-time, ~190 MB)..."
  $zip = "$env:TEMP\jdk17.zip"
  Invoke-WebRequest "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk" -OutFile $zip
  New-Item -ItemType Directory -Force "$HERE\jdk" | Out-Null
  Expand-Archive $zip "$HERE\jdk" -Force
  $jdk = (Get-Item "$HERE\jdk\*\bin\java.exe" | Select-Object -First 1).FullName
  if (-not $jdk) { throw "JDK download failed" }
}
$env:JAVA_HOME = Split-Path -Parent (Split-Path -Parent $jdk)
Ok "JDK: $jdk"

# --- 2) Android SDK command-line tools ----------------------------------------------
Step 2 "Android SDK command-line tools"
$sdkmgr = Get-ChildItem "$SDK\cmdline-tools" -Recurse -Filter sdkmanager.bat -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $sdkmgr) {
  Info "cmdline-tools not found - downloading..."
  New-Item -ItemType Directory -Force "$SDK\cmdline-tools" | Out-Null
  $zip = "$env:TEMP\cmdline-tools.zip"
  Invoke-WebRequest "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" -OutFile $zip
  Expand-Archive $zip "$SDK\cmdline-tools" -Force
  Rename-Item "$SDK\cmdline-tools\cmdline-tools" "$SDK\cmdline-tools\latest" -ErrorAction SilentlyContinue
  $sdkmgr = Get-ChildItem "$SDK\cmdline-tools" -Recurse -Filter sdkmanager.bat | Select-Object -First 1
}
$SM = $sdkmgr.FullName
$AM = Join-Path (Split-Path $SM) "avdmanager.bat"
Ok "sdkmanager: $SM"

# --- 3) SDK packages: platform-tools, emulator, Play-Store system image -------------
Step 3 "Installing emulator + Android 14 Play-Store image (large download, one-time)"
"y`n"*50 | & $SM --licenses | Out-Null
& $SM "platform-tools" "emulator" $IMAGE | Out-Null
$ADB = "$SDK\platform-tools\adb.exe"
$EMU = "$SDK\emulator\emulator.exe"
if (-not (Test-Path $EMU)) { throw "emulator install failed" }
Ok "emulator + system image ready"

# --- 3b) emulator acceleration (only needed when Hyper-V/WHPX is absent) -------------
$accel = (& $EMU -accel-check 2>&1) -join "`n"
if ($accel -notmatch "is installed and usable") {
  Info "no hypervisor detected - installing Android Emulator Hypervisor Driver (AEHD)..."
  try {
    & $SM "extras;google;Android_Emulator_Hypervisor_Driver" | Out-Null
    $inst = Get-ChildItem "$SDK\extras\google\Android_Emulator_Hypervisor_Driver" -Filter "silent_install.bat" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($inst) { & $inst.FullName | Out-Null; Ok "AEHD installed" }
  } catch { Info "AEHD install failed - emulator will be slow; enable 'Windows Hypervisor Platform' in Windows Features instead." }
} else { Ok "hardware acceleration available" }

# --- 4) Create the AVD ---------------------------------------------------------------
Step 4 "Creating AVD '$AVD'"
$avds = & $EMU -list-avds
if ($avds -notcontains $AVD) {
  "no" | & $AM create avd -n $AVD -k $IMAGE -d "pixel_6" --force | Out-Null
  Ok "AVD '$AVD' created"
} else { Ok "AVD '$AVD' already exists" }
# 8 GB laptops: cap the guest at 2 GB RAM so the whole bridge fits comfortably
$cfg = "$env:USERPROFILE\.android\avd\$AVD.avd\config.ini"
if (Test-Path $cfg) {
  $ini = Get-Content $cfg | Where-Object { $_ -notmatch "^hw\.ramSize" }
  $ini += "hw.ramSize=2048"
  $ini | Set-Content $cfg -Encoding ascii
}

# --- 5) Boot once, install & configure droidVNC-NG ----------------------------------
Step 5 "Booting emulator to install droidVNC-NG"
if (((& $ADB devices) -join "`n") -notmatch "emulator-\d+\s+device") {
  Start-Process -FilePath $EMU -ArgumentList @("-avd",$AVD,"-no-boot-anim","-gpu","auto") -WindowStyle Minimized
}
& $ADB wait-for-device
for ($i=0; $i -lt 120; $i++) { if (((& $ADB shell getprop sys.boot_completed) -replace '\s','') -eq "1") { break }; Start-Sleep 2 }
Ok "Android booted"

if (-not (Test-Path $APK)) { throw "droidVNC-NG APK missing at $APK" }
& $ADB install -r $APK | Out-Null
# notifications denied on purpose: droidVNC's connect-"ding" must never play in a demo
& $ADB shell pm revoke $PKG android.permission.POST_NOTIFICATIONS 2>$null
& $ADB shell pm set-permission-flags $PKG android.permission.POST_NOTIFICATIONS user-fixed 2>$null
& $ADB shell appops set $PKG PROJECT_MEDIA allow 2>$null
& $ADB shell settings put secure enabled_accessibility_services "$PKG/$PKG.InputService" 2>$null
& $ADB shell settings put secure accessibility_enabled 1 2>$null
Ok "droidVNC-NG installed and permissioned"

# --- 6) Firewall: let the BlackBerry (on the same Wi-Fi) reach the mirror ------------
Step 6 "Firewall rule for the phone"
try {
  netsh advfirewall firewall delete rule name="BlackBerry Bridge Mirror" | Out-Null
} catch {}
netsh advfirewall firewall add rule name="BlackBerry Bridge Mirror" dir=in action=allow protocol=TCP localport=8080,5900 | Out-Null
Ok "inbound TCP 8080 (phone browser) + 5900 (VNC) allowed"

# --- 7) Auto-start at login + Desktop shortcut ---------------------------------------
Step 7 "Auto-start + Desktop shortcut"
$task = "BlackBerryBridge-AndroidSource"
$start = Join-Path $HERE "start_android_source.ps1"
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$start`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$set     = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
try {
  Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Settings $set -Force -RunLevel Limited | Out-Null
  Ok "Auto-start registered (Task Scheduler: '$task')"
} catch {
  Info "Could not register auto-start. Use the Desktop shortcut instead. ($($_.Exception.Message))"
}
$lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "START BRIDGE.lnk"
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnk)
$sc.TargetPath = Join-Path $ROOT "START-BRIDGE.cmd"
$sc.WorkingDirectory = $ROOT
$sc.Save()
Ok "Desktop shortcut created: START BRIDGE"

# --- Done -----------------------------------------------------------------------------
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch "^(127\.|169\.254\.)" -and $_.InterfaceAlias -notmatch "vEthernet|VMware|Loopback|WSL" } | Select-Object -First 1).IPAddress
Write-Host ""
Write-Host "===================================================================" -ForegroundColor Green
Write-Host " SETUP COMPLETE." -ForegroundColor Green
Write-Host ""
Write-Host " 1. In the emulator window: sign into Google Play, install"
Write-Host "    Instagram / WhatsApp / whatever the phone should run."
Write-Host " 2. Double-click 'START BRIDGE' on the Desktop."
Write-Host " 3. On the BlackBerry: connect to the SAME Wi-Fi as this laptop,"
Write-Host "    open the Browser and go to the address START BRIDGE prints"
Write-Host "    (like http://$ip`:8080/?k=123456 - the code keeps other"
Write-Host "    people on the Wi-Fi out)."
Write-Host "===================================================================" -ForegroundColor Green
