# update.ps1 — BlackBerry Bridge self-updater.
#
# Pulls the latest code straight from the PUBLIC GitHub repo and drops it over this
# folder. No git, no login, no account needed — just internet. Works whether this
# folder was git-cloned OR copied here on a USB stick.
#
# Your machine-specific files are SAFE: the access code, DuckDNS token, and saved URLs
# live in gitignored files that are NOT in the download, so they're never touched.
#
# Run it by double-clicking UPDATE.cmd (which calls this).

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# the folder this script lives in is host-setup\ ; the project root is its parent
$HERE = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT = Split-Path -Parent $HERE

$REPO = "https://github.com/OppaiMaster7/blackberry-bridge"
$ZIP  = "$REPO/archive/refs/heads/master.zip"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   BlackBerry Bridge - UPDATE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[*] Updating folder: $ROOT"
Write-Host "[*] Downloading the latest version from GitHub..."

$tmp   = Join-Path $env:TEMP ("bbbridge_update_" + [guid]::NewGuid().ToString("N"))
$zip   = "$tmp.zip"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
  Invoke-WebRequest -Uri $ZIP -OutFile $zip -UseBasicParsing -TimeoutSec 120
} catch {
  Write-Host ""
  Write-Host "[X] Download failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "    Check the internet connection and try again." -ForegroundColor Red
  Write-Host "    (If it says 404, the repo may still be private - it must be public.)" -ForegroundColor Red
  Write-Host ""
  Read-Host "Press Enter to close"
  exit 1
}

Write-Host "[*] Unpacking..."
Expand-Archive -Path $zip -DestinationPath $tmp -Force

# GitHub zips extract into a single subfolder: blackberry-bridge-master\
$src = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
if (-not $src) {
  Write-Host "[X] Unexpected download contents - nothing to copy." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}

Write-Host "[*] Installing the new files (your access code + settings are kept)..."
# Copy everything from the download over this folder. This OVERWRITES code files but
# never deletes your local-only files (they aren't in the download, so they survive).
Copy-Item -Path (Join-Path $src.FullName "*") -Destination $ROOT -Recurse -Force

# cleanup
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "   UPDATE DONE." -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host " Now double-click START-BRIDGE again to run the new version." -ForegroundColor Yellow
Write-Host " (On the BlackBerry, close the tab and reopen it so it loads fresh.)" -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to close"
