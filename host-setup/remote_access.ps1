# remote_access.ps1 - BlackBerry Bridge: reach the laptop from ANYWHERE with internet.
#
# Publishes the local mirror gateway (127.0.0.1:8080) at a stable, encrypted PUBLIC HTTPS
# URL using Tailscale Funnel. The BlackBerry then opens that URL over any internet
# connection (mobile data, another Wi-Fi) - no VPN app on the phone, no router port
# forwarding, no changing home IP to chase.
#
#   BB10 browser (anywhere) --HTTPS--> https://<machine>.<tailnet>.ts.net/?k=CODE
#                                        --> Tailscale Funnel --> 127.0.0.1:8080 (gateway)
#
# Run ONCE (interactive login the first time). Safe to re-run; idempotent.
#   powershell -ExecutionPolicy Bypass -File remote_access.ps1

$ErrorActionPreference = "Stop"
$HERE = Split-Path -Parent $MyInvocation.MyCommand.Path
function Info($m){ Write-Host "[*] $m" }
function Ok($m){ Write-Host "[+] $m" -ForegroundColor Green }

# --- 1) Tailscale present? install via winget/MSI if not --------------------------------
$TS = $null
foreach ($c in @("$env:ProgramFiles\Tailscale\tailscale.exe",
                 "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe")) {
  if (Test-Path $c) { $TS = $c; break }
}
if (-not $TS) {
  # Direct MSI is used as the primary method: it's deterministic and unattended. (winget
  # can hang waiting on interactive agreements/dependencies, so it's only a last resort.)
  Info "Tailscale not found - downloading the official installer (~40 MB)..."
  $msi = "$env:TEMP\tailscale-setup.msi"
  try {
    Invoke-WebRequest "https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi" -OutFile $msi -UseBasicParsing
    Info "installing Tailscale silently..."
    $p = Start-Process msiexec.exe -ArgumentList "/i","`"$msi`"","/quiet","/norestart" -Wait -PassThru
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { Info "msiexec returned $($p.ExitCode)" }
  } catch {
    Info "MSI path failed ($($_.Exception.Message)); trying winget..."
    try { winget install --id Tailscale.Tailscale -e --silent --accept-source-agreements --accept-package-agreements } catch {}
  }
  foreach ($c in @("$env:ProgramFiles\Tailscale\tailscale.exe",
                   "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe")) {
    if (Test-Path $c) { $TS = $c; break }
  }
  if (-not $TS) { throw "Tailscale install failed - install it from https://tailscale.com/download/windows and re-run." }
}
Ok "Tailscale: $TS"

# --- 2) bring the tailnet up (interactive browser login on first run) -------------------
$status = (& $TS status 2>&1) -join "`n"
if ($status -match "Logged out" -or $status -match "NeedsLogin" -or $LASTEXITCODE -ne 0) {
  Info "logging in to Tailscale (a browser window opens - sign in / create a free account)..."
  & $TS up
}
# wait for a tailnet IP
$ip = $null
for ($i=0; $i -lt 30; $i++) {
  $ip = (& $TS ip -4 2>$null | Select-Object -First 1)
  if ($ip) { break }
  Start-Sleep -Seconds 2
}
if (-not $ip) { throw "Tailscale did not come up - run 'tailscale up' manually and re-run." }
Ok "tailnet address: $ip"

# --- 3) enable Funnel on 8080 (public HTTPS) --------------------------------------------
Info "enabling public Funnel on port 8080..."
# Try the command forms across Tailscale versions; keep the output so we can detect the
# one-time "enable Funnel in the admin console" message and show it to the user.
$funnelOut = ""
$forms = @(
  @("funnel","--bg","8080"),                                   # current (1.58+)
  @("funnel","--bg","http://127.0.0.1:8080"),                  # explicit target
  @("serve","--bg","--https=443","http://127.0.0.1:8080")      # older two-step (serve...)
)
$funnelOk = $false
foreach ($f in $forms) {
  $funnelOut = (& $TS @f 2>&1) -join "`n"
  if ($LASTEXITCODE -eq 0) { $funnelOk = $true; break }
}
if (-not $funnelOk -and $forms[2][0] -eq "serve") {
  # the serve form needs a second command to flip Funnel public
  & $TS funnel --bg 443 on 2>&1 | Out-Null
}

# Personal tailnets must opt in to Funnel ONCE in the admin console. Tailscale prints a
# URL when that's needed — surface it loudly instead of dying silently.
if ($funnelOut -match "https://login\.tailscale\.com\S+") {
  Write-Host ""
  Write-Host "  ONE-TIME STEP: open this link, turn Funnel ON, then run ENABLE-REMOTE again:" -ForegroundColor Yellow
  Write-Host ("     " + $Matches[0]) -ForegroundColor Yellow
  Write-Host ""
}

Start-Sleep -Seconds 2
$fs = (& $TS funnel status 2>&1) -join "`n"
$dns = $null
try { $dns = (& $TS status --json 2>$null | ConvertFrom-Json).Self.DNSName } catch {}
if ($dns) { $dns = $dns.TrimEnd(".") }
$publicUrl = if ($dns) { "https://$dns" } else { "(run 'tailscale funnel status' to see the URL)" }
if ($fs -match "https://\S+\.ts\.net\S*") { Ok "Funnel serving at $($Matches[0])" }
else { Info "Funnel status:`n$fs" }

# --- 4) keep the laptop awake so it's reachable while your cousin is out ----------------
Info "keeping the laptop awake (screen may sleep; the machine won't)..."
powercfg /change standby-timeout-ac 0 2>$null | Out-Null
powercfg /change hibernate-timeout-ac 0 2>$null | Out-Null

# --- 5) persist the URL so START-BRIDGE can print it ------------------------------------
Set-Content -Path "$HERE\bridge_public_url.txt" -Value $publicUrl -Encoding ascii

$key = (Get-Content "$HERE\bridge_access_key.txt" -ErrorAction SilentlyContinue | Select-Object -First 1)
if (-not $key) { $key = "(shown after you run START BRIDGE once)" }

Write-Host ""
Write-Host "===================================================================" -ForegroundColor Green
Write-Host " REMOTE ACCESS IS ON." -ForegroundColor Green
Write-Host ""
Write-Host " From ANYWHERE (mobile data, any Wi-Fi), the BlackBerry browser opens:"
Write-Host ("     {0}/?k={1}" -f $publicUrl, $key) -ForegroundColor Cyan
Write-Host ""
Write-Host " Leave this laptop ON and connected to the internet. START BRIDGE must"
Write-Host " also be running (it serves the mirror; Funnel just publishes it)."
Write-Host "===================================================================" -ForegroundColor Green
