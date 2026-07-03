# deploy-bar.ps1 — deploy the freshly-built BridgeLauncher.bar to the BB10 simulator.
# Runs on the HOST (the bundled Oracle JRE used for deploy is NOT blocked by Smart App
# Control — only the compiler is). Build the .bar first with the Sandbox (BridgeBuild.wsb).
param([string]$Device = "192.168.94.128")
$ErrorActionPreference = "Stop"
$L    = "C:/bbndk/host_10_3_1_12/win32/x86/usr/lib"
$JAVA = "C:/bbndk/features/com.qnx.tools.jre.win32.x86_64_1.7.0.51/jre/bin/java.exe"
$BAR  = "C:\Users\user\Desktop\coding\Blackberry revolution\cascades-app\BridgeLauncher\BridgeLauncher.bar"

if (-not (Test-Path $BAR)) { throw "No BridgeLauncher.bar found - build it in the Sandbox first." }

Write-Host "== terminating old instance ==" -ForegroundColor Cyan
& $JAVA "-Djava.awt.headless=true" "-jar" "$L/BarDeploy.jar" -terminateApp -device $Device -package $BAR 2>&1 |
    Select-String "result::"
Write-Host "== installing + launching ==" -ForegroundColor Cyan
& $JAVA "-Djava.awt.headless=true" "-jar" "$L/BarDeploy.jar" -installApp -launchApp -device $Device -package $BAR 2>&1 |
    Where-Object { $_ -notmatch "^WARNING:|0B/s|####" }
Write-Host "== done ==" -ForegroundColor Green
