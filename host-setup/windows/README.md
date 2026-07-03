# Windows Pro host

Simplest path: Windows Pro (or Enterprise/Education) has built-in RDP. **Home does not** —
if the host is Windows Home, use the Linux/xrdp path or upgrade to Pro.

## Steps (on the host laptop)

1. Open **PowerShell as Administrator**.
2. `Set-ExecutionPolicy -Scope Process Bypass -Force`
3. `.\enable-rdp-host.ps1` — enables RDP, opens the firewall, prints the LAN IP.
4. *(Optional)* `.\setup-kiosk-browser.ps1` — auto-opens the target site app-style in the
   720×720 session.
5. From the dev laptop / simulator's RDP client, connect to the printed IP, **requesting a
   720×720 session**, with a local account that has a password.

## Notes

- **Resolution is client-driven.** Don't try to force 720×720 on the Windows side — set it
  in the BB10 RDP client; Windows honors the request and builds the session at that size.
- **Blank passwords are rejected by RDP.** The host account must have a password.
- **Fully reversible** (brief §12): undo with
  `Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' fDenyTSConnections 1`
  and `Disable-NetFirewallRule -DisplayGroup 'Remote Desktop'`, and delete the startup
  shortcut.
- **Tailscale (Phase 2)** comes after the LAN test passes; then connect to the tailnet IP
  instead of the LAN IP, and set the Tailscale service to auto-start on boot.
