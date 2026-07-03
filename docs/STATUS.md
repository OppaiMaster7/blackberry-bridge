# BlackBerry Bridge — Status & Recap

_Last updated: 2026-06-28_

## TL;DR
Went from an empty folder to **a custom Cascades app running on the BlackBerry 10 simulator**,
with the physical Classic not even in hand. The full dev pipeline (build → package → deploy →
run) is proven. Now building the real app UI.

---

## What's installed & working (dev laptop)

| Component | State | Notes |
|---|---|---|
| VMware Workstation **26** | ✅ | Free personal use. Runs the sim under **Hyper-V coexistence** — Memory Integrity stays ON, no security disabled. |
| Momentics IDE + **BB10 Native SDK 10.3.1.995** | ✅ | At `C:\bbndk`. Registered offline via a hand-written qconfig (BlackBerry's update servers are dead). |
| **BB10 Simulator 10.3.2.281** | ✅ booted | VM at `C:\BB10Simulator\`, extracted straight from the installer payload (its InstallAnywhere GUI fails on Win11). Dev Mode ON. **IP `192.168.94.128`** (VMnet8 NAT, host `192.168.94.1`). |
| BB10 Simulator **10.3.1.995** (version-matched) | ⬇️ downloaded | `sdk-downloads/`, kept for making the proper Qt entry point work later. |
| CLI build pipeline | ✅ | `cascades-app/*/build-sim.sh` — qmake → make → package → deploy → launch, one command. |

### Toolchain gotchas (so we don't relearn them)
- **Java:** the packager/deploy tools must use the NDK's **bundled JRE 1.7**
  (`C:\bbndk\features\com.qnx.tools.jre.win32.x86_64_1.7.0.51\jre\bin\java.exe`) invoked
  *directly*. System JDK 17 breaks them, and cmd.exe ignores forward-slash PATH entries so the
  `.bat` wrappers can't be steered.
- **Entry point:** the 10.3.2 sim's **Qt launcher rejects** our 10.3.1-packaged apps with
  *"Error loading application package: Invalid argument."* Fix: package with a **native entry
  point** (omit `<entryPointType>Qt</entryPointType>`). The Cascades binary loads fine that
  way and `asset:///` QML still resolves. (Proper fix later: build/test on the matched 10.3.1 sim.)

---

## What we proved
1. `HelloBridge` — a Cascades app we wrote — compiled, packaged, deployed, and **rendered on the
   simulator** (C++-built UI, then full QML UI). The brief's viability gate is passed.
2. The simulator launches sideloaded apps; native-entry apps run; QML loads via native entry.

## Architecture reminder (three machines, never conflated)
- **Host** — a dedicated laptop (TBD) that does all compute: RDP server + 720×720 session +
  browser + Tailscale. *For now we test against this dev laptop as a placeholder.*
- **Dev laptop (this one)** — builds/tests the app. Never the production host.
- **The Classic / Simulator** — the terminal; shows the host's 720×720 desktop over RDP.

---

## The app — product definition (refined with sir, 2026-06-28)
The BlackBerry app is a **connection portal** to the host laptop, not a tile launcher:
- **Top:** live connection **status** — Connected / Connecting… / Offline — based on whether the
  phone can actually reach the host.
- **Retry / Try Again** to re-check the connection.
- **Primary action:** enter the mirrored desktop once connected (RDP session, 720×720). Past that
  point "the design comes from the laptop" — the phone just shows the laptop's screen.
- **Offline fallback:** native BB10 (the genuinely good built-in apps).

Open question being designed: explicit **"Enter Desktop"** button vs. seamless auto-enter on
connect. Current call: explicit button (clear mental model; keeps offline mode reachable).

---

## App built — `cascades-app/BridgeLauncher` (see `docs/TONIGHT.md`)
A working BB10 app: **discovers** hosts on the LAN (UDP), **pairs** (auto-pairs a lone host,
remembers it), shows a **live link status** (TCP probe every 5s), techy dark UI, manual host
entry, and a **mirror screen** ready for a real desktop feed. Confirmed on the sim: auto-paired
the dev laptop (DESKTOP-L4N53PI), LINK ONLINE green. Host side: `host-setup/host_agent.py`
(discovery + RDP stand-in).

## Remaining work
- **The mirror client** (the one real blocker): paint the host's desktop on the phone. The
  homemade screen-streamer is AV-blocked (correctly) — use **real RDP/VNC**. Plan:
  `docs/MIRROR-CLIENT-PLAN.md`. Short term: minimal VNC client in-app (testable on sim);
  device: era-appropriate Android RDP `.bar` (Phase 0b, real Classic).
- **Enable real Windows RDP** on a host (one admin command — in MIRROR-CLIENT-PLAN.md).
- **Polish:** real icons; verify square 720×720 layout on real hardware.
- **Undecided:** which physical machine is the host, and its OS.
- **Phase 0b:** real-hardware checks (keyboard-as-mouse-click quirk) when the Classic returns.
