# BlackBerry Bridge

Turn a BlackBerry Classic (BB10) into a usable 2026 internet device — WhatsApp,
Instagram, browsing — **without touching its operating system**. A Windows laptop runs a
real Android phone (emulator with Google Play); the BlackBerry shows and touch-controls
it live.

> The most secure phone ever made, back online — by adding nothing to it that can't be
> removed in thirty seconds.

**Start here → [`INSTALL.md`](INSTALL.md)** — one installer on the laptop, zero installs
on the phone.

## How it works

Two ways the BlackBerry can be the screen:

1. **Real BB10 phone (the product):** the phone's built-in Browser opens
   `http://<laptop>:8080` (served by `host-setup/browser_gateway.py`) — live JPEG mirror
   (~10 fps) with pixel-accurate touch. No app install: BlackBerry's signing servers died
   in 2022, so homemade BB10 apps can't be installed on real devices anymore.
2. **BB10 Simulator (dev demo):** a native Cascades app (`cascades-app/BridgeLauncher`)
   auto-discovers the laptop, auto-launches, and streams over raw VNC.

Both feed off the same source chain:

```
BlackBerry ──HTTP/VNC──> laptop services ──adb──> Android 14 emulator (720×720, Google Play)
                          (relay · keepalive · discovery · gateway, all under a
                           self-healing supervisor started by START-BRIDGE.cmd)
```

## Entry points

| Double-click | What it does |
|---|---|
| `host-setup\Install-BlackBerryBridge.cmd` | One-time laptop setup (downloads/configures everything). |
| `START-BRIDGE.cmd` | Daily: brings the whole source up, prints the phone URL(s). |
| `ENABLE-REMOTE.cmd` | Optional once: publish the mirror to the internet (Tailscale Funnel) so the phone works from anywhere. See `docs/REMOTE-ACCESS.md`. |
| `START-DEMO.cmd` | Dev laptop: same + BB10 simulator VM + app + PASS/FAIL health check. |

## Repository layout

| Path | What lives here |
|---|---|
| `host-setup/` | All laptop-side services, installer, demo scripts. |
| `cascades-app/` | The native BB10 app (simulator target; see `docs/SAFE-BUILD.md` for the build situation). |
| `docs/` | Design brief, status notes, build/mirror documentation. |
| `sdk-downloads/` | BB10 SDK + simulator archives (dev laptop only). |
