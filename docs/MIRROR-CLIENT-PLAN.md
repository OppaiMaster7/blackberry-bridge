# Putting real laptop pixels on the BlackBerry — the plan

The app side is done: discover → pair → live link → mirror screen. The one missing piece is
the **client that decodes and draws the host's desktop**. Here's the honest landscape.

## Two halves
- **Host (server):** must be a *trusted* component. Use **Windows Remote Desktop** (built-in,
  signed) or an established **VNC server** (TightVNC/UltraVNC). Do NOT use a homemade
  screen-streamer — Windows Defender blocks it (correctly; see `TONIGHT.md`).
- **BlackBerry (client):** the genuinely hard part. Must run on BB10 10.3.x.

### Enable the real RDP server (host side) — one admin command
On the host laptop, in an **elevated** PowerShell:
```
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
```
Now port 3389 is a *real* RDP server (replacing the stand-in), and the app's LINK check is
checking a genuine endpoint. (Account must have a password; RDP rejects blank passwords.)

## The BlackBerry client — options, ranked

1. **Era-appropriate Android RDP/VNC client on the REAL Classic (most realistic).**
   The Classic has an ARM Android runtime; a 2014–2016 Microsoft Remote Desktop or
   bVNC/aRDP `.apk` repackaged to `.bar` can run there. **Cannot be tested on the x86
   simulator** (its Android runtime is unreliable/absent), so this waits for the physical
   device — exactly the Phase 0b hardware gate in the brief.

2. **Native BB10 RDP/VNC viewer (works on the simulator, but real work).**
   - The app already has `MirrorClient` (receives + draws frames). Pair it with a *trusted*
     server-side that speaks a simple framed-image protocol, or
   - Build/port **FreeRDP** (the iiordanov clients historically targeted BB10) or a small
     **VNC (RFB) decoder** in C++ inside the Cascades app. RFB is the simpler protocol; a
     minimal RAW-encoding RFB client is a few hundred lines and would let `MirrorClient`'s
     `ImageView` show a real VNC server (TightVNC on the host) — fully testable on the sim.
   - This is the path that gets pixels on the *simulator* without waiting for hardware.

3. **Splashtop / proprietary (fallback).** Works but needs its own streamer; fights the
   self-hosted plan. Brief §8 ranks it last.

## Recommendation
- **Short term (testable now):** implement a minimal **VNC (RFB) client** in the Cascades app
  feeding `MirrorClient`'s ImageView, against a **TightVNC** server (trusted, Defender-safe)
  on the host. This proves the real mirror on the simulator end to end.
- **For the shipping device:** an era-appropriate Android RDP `.bar` on the real Classic,
  validated at the Phase 0b hardware gate (also the only way to test the keyboard-as-mouse
  quirk from the brief).

## Note on the "blocked partially" Defender popup
That was Defender's AMSI flagging the homemade screen-streamer. Nothing was quarantined; the
discovery agent and the app are clean. The lesson is baked into this plan: **trusted server
components only.**
