# enable-rdp-host.ps1
# Run this ON THE DEDICATED HOST LAPTOP (Windows Pro+), NOT on the dev machine.
# Enables built-in RDP, opens the firewall, and reports the LAN IP to point the
# BlackBerry/simulator RDP client at. Resolution is client-driven: set the BB10 RDP
# client to 720x720 and Windows creates the session at exactly that size.
#
# Run elevated:  Right-click PowerShell -> Run as Administrator, then:
#   Set-ExecutionPolicy -Scope Process Bypass -Force; .\enable-rdp-host.ps1

#Requires -RunAsAdministrator

Write-Host "== BlackBerry Bridge :: Windows host RDP setup ==" -ForegroundColor Cyan

# Sanity guard: refuse to run on the dev machine name if you set one here.
# (Optional) Uncomment and set your dev laptop's hostname to hard-block mistakes:
# if ($env:COMPUTERNAME -eq 'YOUR-DEV-LAPTOP-NAME') {
#     throw "This is the DEV machine. The host must be a separate laptop (brief §12)."
# }

# 1. Enable Remote Desktop
Write-Host "Enabling Remote Desktop..." -ForegroundColor Yellow
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
    -Name 'fDenyTSConnections' -Value 0

# 2. Require Network Level Authentication (more secure; clients must support it)
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
    -Name 'UserAuthentication' -Value 1

# 3. Open the firewall for RDP
Write-Host "Opening firewall for Remote Desktop..." -ForegroundColor Yellow
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'

# 4. Confirm the RDP service is running
$svc = Get-Service -Name TermService
if ($svc.Status -ne 'Running') { Start-Service TermService }
Write-Host ("TermService: {0}" -f (Get-Service TermService).Status)

# 5. Report LAN IPv4 addresses to use as the connection target
Write-Host "`nPoint the BB10 RDP client at one of these IPs (port 3389):" -ForegroundColor Green
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' } |
    Select-Object IPAddress, InterfaceAlias |
    Format-Table -AutoSize

Write-Host @"

NEXT:
  - On the BB10 RDP client, request a 720x720 session (NOT fullscreen-of-host).
  - Log in with a LOCAL Windows account that has a password (RDP rejects blank passwords).
  - For the framed-browser experience, also run setup-kiosk-browser.ps1 (optional).
  - Once LAN works, install Tailscale (Phase 2) and use the tailnet IP instead.
"@ -ForegroundColor Cyan
