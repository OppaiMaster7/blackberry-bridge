# Linux + xrdp host

Use this if the host laptop isn't Windows Pro. `xrdp` gives you a standard RDP server that
the BB10 RDP client connects to natively (no proprietary streamer, unlike Splashtop).

## Steps (on the host laptop)

1. Copy `setup-xrdp-720.sh` to the host.
2. `sudo bash setup-xrdp-720.sh`
3. It installs xrdp + XFCE, enables the service, opens port 3389, and prints the host's IPs.
4. From the dev laptop / simulator's RDP client, connect to a printed IP, **requesting a
   720×720 session**, logging in as a real Linux user.

## Notes on 720×720

- **Xorg backend (default):** honors the client-requested resolution — set 720×720 in the
  BB10 RDP client and you're done.
- **Xvnc backend:** can be pinned to a fixed geometry. Flip `PIN_GEOMETRY=true` in the
  script if a client won't request the size cleanly.
- **XFCE** is chosen because it's light and renders crisply over RDP — important on a 720
  square where wasted chrome shows. GNOME/KDE over xrdp are heavier and can fight the
  session size.

## Reversibility (brief §12)

```bash
sudo systemctl disable --now xrdp
sudo apt-get remove --purge xrdp xorgxrdp   # or dnf remove
```

Nothing here touches the BlackBerry; it's all host-side and removable.

## Tailscale (Phase 2)

After the LAN test passes: `curl -fsSL https://tailscale.com/install.sh | sh`, then
`sudo tailscale up`, and `sudo systemctl enable --now tailscaled` so it auto-starts on boot.
Connect via the tailnet IP thereafter.
