# Host setup — the 720×720 RDP appliance

This is for the **dedicated host laptop**, *not* this dev machine (brief §3, §12). Pick the
folder that matches the host's OS:

- **[`windows/`](windows/)** — Windows Pro (or better). Built-in RDP. Simplest path.
- **[`linux/`](linux/)** — any Linux. `xrdp`. Use if the host isn't Windows Pro.

## How the 720×720 rule actually works (read once)

> Do **not** mirror the host's full desktop. The session must *be* 720×720.

- **An RDP session is created at the resolution the client requests.** When the BB10 RDP
  client asks for 720×720, the host spins up a desktop session that exact size — apps land
  framed, not a giant desktop panned onto a square. This is *why* RDP beats VNC here, and it
  means **most of the 720×720 work happens on the client side** (set aRDP to 720×720).
- The host's job is therefore mostly: **enable RDP, allow the connection, and make the
  720×720 session pleasant** (browser auto-launching maximized at the target sites).
- On **Windows**, the client-requested size is honored automatically — nothing to force
  server-side.
- On **Linux/xrdp**, the Xorg backend also honors the client size; the older Xvnc backend
  lets you pin geometry explicitly. The script covers both.

## Test target for Phase 0

Until the dedicated host laptop is chosen (brief §13 — still unspecified), you can run the
host scripts on **any spare machine on the same Wi-Fi** as a placeholder, then point the
simulator's RDP client at that machine's LAN IP. Just don't make it *this* dev laptop, and
don't use `localhost` (brief §12).

Tailscale (brief §2/Phase 2) is added *after* the LAN test works — get the pipe proven on
plain Wi-Fi first.
