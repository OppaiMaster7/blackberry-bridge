# start_android_source.ps1 — BlackBerry Bridge: bring up the entire Android content source.
#
# Boots the Android emulator (real apps + internet), starts droidVNC-NG with screen
# capture + input enabled, forwards its port to the host, and runs the supervisor that
# keeps the relay/keepalive/discovery services alive so the BlackBerry sim (which reaches
# the host at 192.168.94.1) can mirror the live Android screen.
#
# IDEMPOTENT: safe to re-run any time — it first kills stale bridge services so nothing
# is ever duplicated (duplicate relays fighting over port 5900 caused random drops).
#
#   BB10 sim --> 192.168.94.1:5900 (relay) --> 127.0.0.1:5901 (adb) --> AVD:5900 (droidVNC-NG)
#
# Usage:  powershell -ExecutionPolicy Bypass -File start_android_source.ps1

$ErrorActionPreference = "Stop"
$SDK = "$env:LOCALAPPDATA\Android\Sdk"
$ADB = "$SDK\platform-tools\adb.exe"
$EMU = "$SDK\emulator\emulator.exe"
$AVD = "BridgePhone"
$PKG = "net.christianbeier.droidvnc_ng"
$HERE = Split-Path -Parent $MyInvocation.MyCommand.Path

# 0) kill stale bridge services (relay/keepalive/supervisor/host_agent) so re-runs never
#    stack duplicates. Only pythons running OUR scripts are touched.
Write-Host "[*] cleaning up stale bridge services..."
Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" | Where-Object {
  $_.CommandLine -match 'vnc_relay\.py|vnc_keepalive\.py|bridge_supervisor\.py|host_agent\.py|browser_gateway\.py'
} | ForEach-Object {
  Write-Host ("    killing PID {0} ({1})" -f $_.ProcessId, ($_.CommandLine -replace '.*\\',''))
  try { Stop-Process -Id $_.ProcessId -Force -Confirm:$false -ErrorAction Stop } catch {}
}

function Wait-Boot {
  Write-Host "[*] waiting for Android to boot..."
  for ($i=0; $i -lt 90; $i++) {
    $b = (& $ADB shell getprop sys.boot_completed 2>$null) -replace '\s',''
    if ($b -eq "1") { Write-Host "[+] booted"; return $true }
    Start-Sleep -Seconds 2
  }
  throw "emulator did not boot in time"
}

# 0b) Ensure the AVD advertises a hardware keyboard BEFORE boot: then Android won't pop its
#     on-screen keyboard when a text field is focused, so the BlackBerry's PHYSICAL keys
#     (injected via browser_gateway /key) are the only keyboard. Editing config.ini only
#     takes effect on a cold start, which is why it's done here before launch.
$cfg = Join-Path $env:USERPROFILE ".android\avd\$AVD.avd\config.ini"
if (Test-Path $cfg) {
  $lines = Get-Content $cfg
  if ($lines -match '^hw\.keyboard\s*=\s*no') {
    ($lines -replace '^hw\.keyboard\s*=\s*no', 'hw.keyboard = yes') | Set-Content $cfg
    Write-Host "[*] set hw.keyboard = yes in the AVD (keeps the soft keyboard hidden)"
  }
}

# 1) emulator (detached) if not already running. Audio ON (Instagram/WhatsApp sound plays
#    through the laptop speakers); only the NOTIFICATION stream is muted below, so
#    droidVNC's client-connect "ding" stays silent.
$dev = (& $ADB devices) -join "`n"
if ($dev -notmatch "emulator-\d+\s+device") {
  Write-Host "[*] launching emulator $AVD (detached, tuned for 8GB laptops)..."
  # -memory 2048: cap guest RAM at 2GB so a low-end 8GB laptop keeps ~6GB for Windows and
  #   never swaps (swapping is what makes the mirror stutter). -cores 4: enough for smooth
  #   capture without starving the host. -gpu auto picks host acceleration when available.
  Start-Process -FilePath $EMU `
    -ArgumentList @("-avd",$AVD,"-no-snapshot-save","-no-boot-anim","-gpu","auto",
                    "-memory","2048","-cores","4","-netdelay","none","-netspeed","full") `
    -WindowStyle Minimized
} else { Write-Host "[=] emulator already running" }
& $ADB wait-for-device
Wait-Boot | Out-Null

# mute ONLY notifications (stream 5): media/video sound stays on, connect-dings don't
& $ADB shell cmd media_session volume --stream 5 --set 0 2>$null | Out-Null
& $ADB shell settings put system notification_volume 0 2>$null | Out-Null

# 2) droidVNC-NG permissions (idempotent): screen capture + input (accessibility).
#    POST_NOTIFICATIONS is DENIED on purpose: its "client connected" notification is the
#    annoying ding; the foreground service works fine without posting it. Stream volumes
#    proved unreliable for this (the system resyncs notification volume with ring).
Write-Host "[*] configuring droidVNC-NG permissions (notifications OFF)..."
& $ADB shell pm revoke $PKG android.permission.POST_NOTIFICATIONS 2>$null
& $ADB shell pm set-permission-flags $PKG android.permission.POST_NOTIFICATIONS user-fixed 2>$null
& $ADB shell appops set $PKG PROJECT_MEDIA allow 2>$null
& $ADB shell settings put secure enabled_accessibility_services "$PKG/$PKG.InputService" 2>$null
& $ADB shell settings put secure accessibility_enabled 1 2>$null

# 3) 720x720 square FIRST so the Android screen fills the BlackBerry, and droidVNC starts
#    (and stays) at this geometry — resizing after start restarted its server and dropped
#    every connected client. 3-button navigation puts BACK/HOME *inside* the mirror so
#    they're tappable from the BlackBerry (gesture nav is unusable through a mirror).
Write-Host "[*] setting Android to 720x720 square + 3-button nav..."
& $ADB shell wm size 720x720 2>$null
& $ADB shell wm density 280 2>$null
& $ADB shell cmd overlay enable com.android.internal.systemui.navbar.threebutton 2>$null
# Physical-keyboard typing: the BlackBerry's real keys are injected as key events
# (browser_gateway /key), so keep Android's ON-SCREEN keyboard hidden - it would cover the
# mirror. hw.keyboard=yes in the AVD makes Android believe a hardware keyboard is attached;
# this setting stops it showing the soft keyboard anyway when a field is focused.
& $ADB shell settings put secure show_ime_with_hard_keyboard 0 2>$null
Start-Sleep -Seconds 2

# 4) forward guest 5900 -> host 127.0.0.1:5901
Write-Host "[*] adb forward 5901 -> guest 5900..."
& $ADB forward tcp:5901 tcp:5900 | Out-Null

# helper: locate droidVNC's START/STOP toggle via uiautomator (no hardcoded coords). On a
# 720x720 square the button sits BELOW the fold, so scroll to the bottom before dumping.
function Get-VncToggle {
  param([switch]$Scroll)
  if ($Scroll) { 1..2 | ForEach-Object { & $ADB shell input swipe 360 550 360 120 150 2>$null | Out-Null } }
  & $ADB shell uiautomator dump /sdcard/bridge_ui.xml 2>$null | Out-Null
  $xml = & $ADB shell cat /sdcard/bridge_ui.xml 2>$null
  if (-not $xml) { return $null }
  $m = [regex]::Match($xml, 'text="(START|STOP)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
  if (-not $m.Success) {
    $m = [regex]::Match($xml, 'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*text="(START|STOP)"')
    if (-not $m.Success) { return $null }
    $x = ([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2
    $y = ([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2
    return @{ x=[int]$x; y=[int]$y; label=$m.Groups[5].Value }
  }
  $x = ([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2
  $y = ([int]$m.Groups[3].Value + [int]$m.Groups[5].Value) / 2
  return @{ x=[int]$x; y=[int]$y; label=$m.Groups[1].Value }
}

# helper: dismiss a "System UI isn't responding" / "App isn't responding" ANR if present
function Clear-Anr {
  & $ADB shell uiautomator dump /sdcard/anr.xml 2>$null | Out-Null
  $xml = & $ADB shell cat /sdcard/anr.xml 2>$null
  if ($xml -match "isn.t responding") {
    $w = [regex]::Match($xml, 'text="Wait"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
    if ($w.Success) {
      $x = ([int]$w.Groups[1].Value + [int]$w.Groups[3].Value) / 2
      $y = ([int]$w.Groups[2].Value + [int]$w.Groups[4].Value) / 2
      & $ADB shell input tap ([int]$x) ([int]$y)
      Write-Host "    dismissed a 'not responding' dialog"
      Start-Sleep -Seconds 1
    }
  }
}

# helper: does droidVNC complete an RFB handshake AND serve one frame? (capture working)
function Test-Vnc {
  $py = @'
import socket,struct,sys
def rd(s,n):
    b=b""
    while len(b)<n:
        c=s.recv(n-len(b))
        if not c: raise SystemExit(1)
        b+=c
    return b
try:
    s=socket.create_connection(("127.0.0.1",5901),timeout=6)
    if rd(s,12)[:7]!=b"RFB 003": raise SystemExit(1)
    s.sendall(b"RFB 003.008\n"); n=rd(s,1)[0]; rd(s,n); s.sendall(bytes([1]))
    if struct.unpack(">I",rd(s,4))[0]!=0: raise SystemExit(1)
    s.sendall(bytes([1])); w,h=struct.unpack(">HH",rd(s,4)); rd(s,16); nl=struct.unpack(">I",rd(s,4))[0]; rd(s,nl)
    spf=bytearray(20); spf[4]=32;spf[5]=24;spf[6]=1;spf[7]=1;spf[9]=255;spf[11]=255;spf[13]=255;spf[14]=24;spf[15]=16;spf[16]=8
    s.sendall(bytes(spf)); s.sendall(bytes([2,0,0,1,0,0,0,0]))
    s.sendall(bytes([3,0,0,0,0,0,(w>>8)&255,w&255,(h>>8)&255,h&255]))
    if rd(s,1)[0]!=0: raise SystemExit(1)
    rd(s,1); nr=struct.unpack(">H",rd(s,2))[0]
    rx,ry,rw,rh=struct.unpack(">HHHH",rd(s,8)); rd(s,4); rd(s,rw*rh*4)
    raise SystemExit(0)
except SystemExit as e: sys.exit(e.code if isinstance(e.code,int) else 1)
except Exception: sys.exit(1)
'@
  $py | & python - 2>$null
  return ($LASTEXITCODE -eq 0)
}

# 5) start droidVNC-NG server and verify capture; self-heal if needed
Write-Host "[*] starting droidVNC-NG server (with capture verification)..."
$ok = $false
for ($try=1; $try -le 5; $try++) {
  if (Test-Vnc) { Write-Host "[+] VNC server serving frames (capture OK)"; $ok = $true; break }
  Clear-Anr
  # re-assert both permissions every attempt: a force-stop/ANR can drop the accessibility
  # grant (droidVNC then pops an "Accessibility disabled" dialog instead of starting)
  & $ADB shell appops set $PKG PROJECT_MEDIA allow 2>$null
  & $ADB shell settings put secure enabled_accessibility_services "$PKG/$PKG.InputService" 2>$null
  & $ADB shell settings put secure accessibility_enabled 1 2>$null
  & $ADB shell am start -n "$PKG/.MainActivity" | Out-Null
  Start-Sleep -Seconds 3
  Clear-Anr
  $btn = Get-VncToggle -Scroll        # scroll: the button is below the fold at 720x720
  if ($btn) {
    Write-Host ("    tapping {0} at {1},{2}" -f $btn.label, $btn.x, $btn.y)
    & $ADB shell input tap $btn.x $btn.y
    Start-Sleep -Seconds 2
    Clear-Anr                          # an "enable accessibility?" dialog can appear here
  } else {
    Write-Host "    toggle not found - retrying"
  }
  Start-Sleep -Seconds 3
  if (Test-Vnc) { Write-Host "[+] VNC server serving frames (capture OK)"; $ok = $true; break }
  Write-Host "[!] handshake/capture failed (try $try) - cycling server..."
}
if (-not $ok) { Write-Host "[!] WARNING: droidVNC not verified - the supervisor will keep retrying" }

# 6) supervisor (detached) — runs relay + capture-keepalive + discovery agent, restarts any
#    of them if they die, and cycles droidVNC if capture ever stalls. Single instance
#    guaranteed by a lock port; this is what keeps the mirror alive unattended.
Write-Host "[*] starting service supervisor (relay + keepalive + discovery, self-healing)..."
Start-Process -FilePath "python" -ArgumentList @("`"$HERE\bridge_supervisor.py`"") -WindowStyle Hidden

Start-Sleep -Seconds 2
Write-Host ""
Write-Host "[DONE] Android source is live."
Write-Host "       The BlackBerry app links and launches the mirror automatically."
Write-Host "       Sign into Instagram/WhatsApp via Play Store in the emulator window."
