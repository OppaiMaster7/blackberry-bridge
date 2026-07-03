# update.ps1 — BlackBerry Bridge self-updater.
#
# Pulls the latest code straight from the PUBLIC GitHub repo and drops it over the
# project folder. No git, no login, no account needed — just internet. Works whether
# the folder was git-cloned OR copied here on a USB stick.
#
# Your machine-specific files are SAFE: the access code, DuckDNS token, and saved URLs
# live in gitignored files that are NOT in the download, so they're never touched.
#
# -Root <path>  the project folder to update. UPDATE.cmd passes this in. If omitted,
#               it's derived from where this script sits (host-setup\ -> parent).

param([string]$Root)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not $Root) {
  $HERE = Split-Path -Parent $MyInvocation.MyCommand.Path
  $Root = Split-Path -Parent $HERE
}
$Root = $Root.TrimEnd('\')

$REPO = "https://github.com/OppaiMaster7/blackberry-bridge"
$ZIP  = "$REPO/archive/refs/heads/master.zip"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   BlackBerry Bridge - UPDATE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[*] Updating folder: $Root"
Write-Host "[*] Downloading the latest version from GitHub..."

$tmp = Join-Path $env:TEMP ("bbbridge_update_" + [guid]::NewGuid().ToString("N"))
$zip = "$tmp.zip"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

# Download the zip. curl.exe (built into Windows 10/11) is the most reliable for large
# binaries; fall back to .NET WebClient. Invoke-WebRequest is avoided on purpose - it
# corrupts/aborts big binary downloads on Windows PowerShell 5.1.
$ok = $false
$curl = (Get-Command curl.exe -ErrorAction SilentlyContinue)
if ($curl) {
  & curl.exe -sL --fail $ZIP -o $zip
  if ((Test-Path $zip) -and (Get-Item $zip).Length -gt 100000) { $ok = $true }
}
if (-not $ok) {
  try { (New-Object Net.WebClient).DownloadFile($ZIP, $zip)
        if ((Test-Path $zip) -and (Get-Item $zip).Length -gt 100000) { $ok = $true } } catch {}
}
if (-not $ok) {
  Write-Host ""
  Write-Host "[X] Download failed. Check the internet connection and try again." -ForegroundColor Red
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

if (-not (Test-Path $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }

Write-Host "[*] Installing the new files (your access code + settings are kept)..."
# Copy everything from the download over the project folder. This OVERWRITES code files
# but never deletes your local-only files (they aren't in the download, so they survive).
Copy-Item -Path (Join-Path $src.FullName "*") -Destination $Root -Recurse -Force

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
