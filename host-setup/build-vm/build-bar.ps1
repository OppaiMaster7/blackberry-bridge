# build-bar.ps1 — runs INSIDE Windows Sandbox to compile BridgeLauncher.bar.
# (The host can't run the 2014 QNX compiler because Smart App Control blocks it; the
#  Sandbox has no SAC, so it builds here. Output .bar lands in the shared project folder.)

# log everything to the shared folder so the host can read the result
try { Start-Transcript -Path "C:\build\build.log" -Force | Out-Null } catch {}
$ErrorActionPreference = "Stop"
trap { Write-Host "BUILD FAILED: $_" -ForegroundColor Red; try { Stop-Transcript | Out-Null } catch {}; }
$env:QNX_HOST          = "C:/bbndk/host_10_3_1_12/win32/x86"
$env:QNX_TARGET        = "C:/bbndk/target_10_3_1_995/qnx6"
$env:QNX_CONFIGURATION  = "C:\qnxconfig"
$env:PATH              = "$($env:QNX_HOST)/usr/bin;$env:PATH"

$BIN  = "$($env:QNX_HOST)/usr/bin"
$L    = "$($env:QNX_HOST)/usr/lib"
$JAVA = "C:/bbndk/features/com.qnx.tools.jre.win32.x86_64_1.7.0.51/jre/bin/java.exe"
$PROJ = "C:\BridgeLauncher"
$SPEC = "$($env:QNX_TARGET)/usr/share/qt4/mkspecs/blackberry-x86-qcc"
$CP   = @("EccpressoJDK15ECC.jar","EccpressoAll.jar","TrustpointAll.jar","TrustpointJDK15.jar",
         "TrustpointProviders.jar","BarPackager.jar","BarSigner.jar","BarDeploy.jar","BarAir.jar") |
        ForEach-Object { "$L/$_" }
$CP = ($CP -join ";")

Set-Location $PROJ
Write-Host "== cleaning previous build ==" -ForegroundColor Cyan
Remove-Item -Force -ErrorAction SilentlyContinue Makefile, BridgeLauncher, BridgeLauncher.bar,
    main.o, VncClient.o, moc_VncClient.o

Write-Host "== [1/3] qmake ==" -ForegroundColor Cyan
& "$BIN/qmake.exe" -spec $SPEC BridgeLauncher.pro CONFIG+=debug
if ($LASTEXITCODE -ne 0) { throw "qmake failed" }

Write-Host "== [2/3] make ==" -ForegroundColor Cyan
& "$BIN/make.exe" 2>&1 | Tee-Object -FilePath "C:\build\make.log"
if (-not (Test-Path "$PROJ\BridgeLauncher")) { throw "compile/link failed - see make.log" }

Write-Host "== [3/3] package (.bar) ==" -ForegroundColor Cyan
& $JAVA "-Djava.awt.headless=true" "-Xmx512M" "-cp" $CP `
    com.qnx.bbt.nativepackager.BarNativePackager -devMode `
    -package BridgeLauncher.bar bar-descriptor.xml
if (-not (Test-Path "$PROJ\BridgeLauncher.bar")) { throw "packaging failed - no .bar" }

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host " BUILD OK -> BridgeLauncher.bar is in the shared folder." -ForegroundColor Green
Write-Host " Back on the HOST, deploy it with host-setup\deploy-bar.ps1" -ForegroundColor Green
Write-Host " (You can close this Sandbox window now.)" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
try { Stop-Transcript | Out-Null } catch {}
