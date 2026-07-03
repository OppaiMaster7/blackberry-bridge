# remote_failsafe.ps1 - BlackBerry Bridge: plain-HTTP "from anywhere" BACKUP path.
#
# Use this ONLY if the Tailscale (HTTPS) remote URL shows a certificate/security warning on
# the old BlackBerry browser. This serves the SAME mirror over plain http:// (no certificate
# at all), so even a 2014 browser renders it. The 6-digit access code + brute-force lockout
# are what protect the exposed port.
#
#   BB10 browser (anywhere) --HTTP--> http://<public-ip-or-duckdns>:8080/?k=CODE
#                                       --> home router :8080 --> laptop 192.168.x.x:8080
#
# What it does automatically:
#   - confirms the gateway is listening on 8080
#   - makes sure Windows Firewall allows inbound 8080
#   - tries to open the router port (UPnP); if the router refuses, prints exact manual steps
#   - optional stable name via DuckDNS (host-setup\duckdns.txt = "yourname  your-token")
#   - prints the exact http:// URL (with the access code) and saves it for START BRIDGE
#
#   Run:  powershell -ExecutionPolicy Bypass -File remote_failsafe.ps1
#         (or just double-click ENABLE-FAILSAFE.cmd)

$ErrorActionPreference = "Stop"
$HERE = Split-Path -Parent $MyInvocation.MyCommand.Path
function Info($m){ Write-Host "[*] $m" }
function Ok($m){ Write-Host "[+] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }

$PORT = 8080

# --- 0) is the gateway actually up on 8080? ---------------------------------------------
$up = $false
try { $c = New-Object Net.Sockets.TcpClient; $c.Connect("127.0.0.1",$PORT); $up = $c.Connected; $c.Close() } catch {}
if ($up) { Ok "mirror gateway is listening on $PORT" }
else { Warn "nothing is listening on $PORT yet - run START BRIDGE first, then re-run this. (Continuing so you get the URL.)" }

# --- 1) firewall: allow inbound 8080 ----------------------------------------------------
# python.exe usually already has an inbound Allow (covers the gateway). If not, add a port
# rule. Adding a rule needs admin; if we're not elevated we just report what to do.
$covered = $false
try {
  $covered = [bool](Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True -ErrorAction SilentlyContinue |
    Where-Object {
      $p = $_ | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
      $a = $_ | Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue
      ($p.LocalPort -eq $PORT) -or ($a.Program -match 'python')
    } | Select-Object -First 1)
} catch {}
if ($covered) { Ok "Windows Firewall already allows the mirror inbound" }
else {
  try {
    New-NetFirewallRule -DisplayName "BlackBerry Bridge 8080" -Direction Inbound -Action Allow `
      -Protocol TCP -LocalPort $PORT -Profile Any -ErrorAction Stop | Out-Null
    Ok "added firewall rule for inbound $PORT"
  } catch {
    Warn "couldn't add a firewall rule (need admin). If the phone can't connect, run this as Administrator once, or allow python.exe when Windows prompts."
  }
}

# --- 2) access code ---------------------------------------------------------------------
$key = (Get-Content "$HERE\bridge_access_key.txt" -ErrorAction SilentlyContinue | Select-Object -First 1)
if ($key) { $key = $key.Trim() } else { $key = "(run START BRIDGE once to generate the code)" }

# --- 3) public + LAN IP -----------------------------------------------------------------
$pub = $null
foreach ($u in @("https://api.ipify.org","https://ifconfig.me/ip","https://icanhazip.com")) {
  try { $pub = (Invoke-RestMethod -Uri $u -TimeoutSec 8).ToString().Trim(); if ($pub) { break } } catch {}
}
$lan = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
  $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and
  $_.InterfaceAlias -notmatch 'vEthernet|VMware|Loopback|WSL' } | Select-Object -First 1).IPAddress
if ($pub) { Ok "home public IP: $pub" } else { Warn "couldn't detect the public IP (no internet?)"; $pub = "<your-public-ip>" }
Info "this laptop's LAN IP: $lan"

# --- 4) optional DuckDNS stable name ----------------------------------------------------
# duckdns.txt (in host-setup) should contain one line: "yourname  your-duckdns-token"
# Get a free name + token at https://www.duckdns.org (sign in with Google/GitHub, 30 sec).
$host_for_url = $pub
$cfg = "$HERE\duckdns.txt"
$dd = $null
if (Test-Path $cfg) {
  $line = (Get-Content $cfg | Where-Object { $_ -and -not $_.StartsWith("#") } | Select-Object -First 1)
  if ($line) { $dd = ($line -split '[,\s]+') | Where-Object { $_ } }
}
if (-not $dd -and [Environment]::UserInteractive) {
  try {
    Write-Host ""
    Write-Host "Optional: a free DuckDNS name makes the address stable even when the home IP changes."
    Write-Host "  (Skip with just Enter - the raw public IP works fine for today.)"
    $domIn = Read-Host "  DuckDNS name (the part before .duckdns.org), or Enter to skip"
    if ($domIn) {
      $tokIn = Read-Host "  DuckDNS token"
      if ($tokIn) { $dd = @($domIn.Trim(), $tokIn.Trim()); Set-Content -Path $cfg -Value ("{0}  {1}" -f $dd[0], $dd[1]) -Encoding ascii }
    }
  } catch {}
}
if ($dd -and $dd.Count -ge 2) {
  $dom = $dd[0]; $tok = $dd[1]
  try {
    $r = Invoke-RestMethod -Uri ("https://www.duckdns.org/update?domains={0}&token={1}&ip={2}" -f $dom,$tok,$pub) -TimeoutSec 10
    if ("$r".Trim() -eq "OK") { Ok "DuckDNS updated: $dom.duckdns.org -> $pub"; $host_for_url = "$dom.duckdns.org" }
    else { Warn "DuckDNS did not accept the update (check the name/token in duckdns.txt) - using the raw IP" }
  } catch { Warn "DuckDNS update failed ($($_.Exception.Message)) - using the raw IP" }
}

# --- 5) try to open the router port automatically (UPnP) --------------------------------
$forwarded = $false
try {
  $nat = New-Object -ComObject HNetCfg.NATUPnP
  $col = $nat.StaticPortMappingCollection
  if ($col -ne $null) {
    try { $col.Remove($PORT,"TCP") } catch {}
    $col.Add($PORT,"TCP",$PORT,$lan,$true,"BlackBerry Bridge") | Out-Null
    $forwarded = $true
    Ok "router port opened automatically via UPnP ($PORT -> $lan`:$PORT)"
  }
} catch {}
if (-not $forwarded) {
  Warn "couldn't auto-open the router (UPnP off/unavailable). Do this ONCE on the home router:"
  Write-Host "      1. Open the router admin page (usually http://192.168.1.1 in a browser)."
  Write-Host "      2. Find 'Port Forwarding' (sometimes under Advanced / NAT / Virtual Server)."
  Write-Host ("      3. Forward external TCP {0}  ->  {1}  port {0}." -f $PORT, $lan)
  Write-Host "      4. Save. That's the only manual step; it sticks until you remove it."
}

# --- 6) final URL + persist -------------------------------------------------------------
$url = "http://{0}:{1}/?k={2}" -f $host_for_url, $PORT, $key
Set-Content -Path "$HERE\bridge_failsafe_url.txt" -Value ("http://{0}:{1}" -f $host_for_url,$PORT) -Encoding ascii

Write-Host ""
Write-Host "===================================================================" -ForegroundColor Green
Write-Host " PLAIN-HTTP FAILSAFE IS SET." -ForegroundColor Green
Write-Host ""
Write-Host " On the BlackBerry browser, from anywhere with internet, open:"
Write-Host ("     " + $url) -ForegroundColor Cyan
Write-Host ""
if (-not $forwarded) { Write-Host " (Do the one router port-forward step above first.)" -ForegroundColor Yellow; Write-Host "" }
Write-Host " No certificate is involved, so old browsers won't show a security warning."
Write-Host " Keep this laptop ON with START BRIDGE running. Keep the ?k= code secret."
Write-Host "===================================================================" -ForegroundColor Green
