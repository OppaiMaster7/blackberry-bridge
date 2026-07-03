# BlackBerry Bridge — Project Kickoff Brief

> Reference document for the whole build. Paste relevant sections to Claude Code as work begins. Source project root: `O:\coding\BlackBerryBridge\`.

---

## 0. The one-line goal

Turn a BlackBerry Classic (BB10 10.3.3) into a usable 2026 internet device — WhatsApp, YouTube, browsing, AI search — without touching its operating system. The Classic becomes a **terminal**; an old laptop does **all** the computing; a native BlackBerry app connects to it, the laptop's screen (scaled to the Classic's exact resolution) is streamed across, and that window is where the modern internet lives.

The most secure phone ever made, back online — by adding nothing to it that can't be removed in thirty seconds.

---

## 1. What this is NOT (read first — saves a wasted week)

- **NOT a custom OS / ROM / firmware.** The Classic's bootloader is locked and its boot chain is cryptographically signed by BlackBerry, whose keys died with the company. Custom firmware is impossible *and* pointless here — the whole architecture depends on leaving the OS alone.
- **NOT "flashing" anything.** The app is **sideloaded** over USB in Development Mode. Reversible, no root, no system-partition access. The word "flash" belongs to the firmware path we are deliberately avoiding.
- **NOT running WhatsApp / Instagram / YouTube *on* the BlackBerry.** Those run in a browser on the laptop. The Classic only displays the result. A decade-old QNX phone cannot and will not execute modern apps — every plan that exists routes them through the host.

---

## 2. Target device (the unit in hand)

| | |
|---|---|
| Model | BlackBerry Classic (SQC100-x) |
| Software Release | 10.3.3.1435 |
| OS Version | 10.3.3.2163 |
| Build ID | 903035 |
| Crypto Kernel | 5.6.2.44214 / WLAN 1.1 |
| **Screen** | **720 × 720, 1:1 square — the single defining constraint of this project** |
| Input | Physical QWERTY keyboard + optical trackpad on the keys |
| Android runtime | ≈ Android 4.3 (Jelly Bean) — determines which sideloaded Android clients will run |
| Radios | Wi-Fi + Bluetooth — fully functional. The hardware is fine; only the software ecosystem is dead. |

The square 720×720 screen drives every UI and resolution decision below. Forget it for one step and the result looks cheap.

**Current status: the physical unit is not in hand** (cousin's phone, on loan). Everything in this brief through Phase 0 is designed to be fully provable without it — see §9 below.

---

## 3. Architecture — three pieces, two machines (do not conflate them)

**1. The host (a dedicated old laptop — NOT the machine you're developing on)** — does 100% of the runtime computing. Runs:
- a remote-desktop **server** (RDP),
- a desktop **session forced to ~720×720**,
- a **browser** with the target sites ready,
- **Tailscale** for reachability.
This machine sits on, powered up, waiting for the BlackBerry to connect. It is a dedicated appliance, not your everyday laptop.

**2. The dev machine (this laptop)** — where the app is actually built and tested. Runs Claude Code, the BB10 Native SDK, Momentics IDE, and the **BB10 Simulator** (§9). It never serves the production RDP session — it only builds and tests the client that will eventually run on real hardware. Keeping these roles apart means dev work, reboots, and experiments never interrupt or risk the thing that's actually supposed to be reachable.

**3. The link (Tailscale)** — a private mesh that auto-starts with the host. Reachable on home Wi-Fi *and* anywhere else, with **zero port forwarding** and no exposure to the open internet.

**4. The client (BlackBerry app)** — a native Cascades launcher with two modes (see §7). In Online mode it opens a maximized remote-desktop session, maps the keyboard + trackpad, and reconnects cleanly when the link blinks.

---

## 4. Protocol decision: RDP, not VNC

RDP wins on three counts that matter here: tighter input, lower bandwidth, and it doesn't fall apart the moment something on screen moves. Generic VNC mirrors a fixed existing display and lags on motion — that panning, blurry experience *is* the cheap-remote-desktop reputation we're avoiding.

**Bonus — RDP solves the 720×720 rule almost for free:** an RDP session is created at the resolution the *client requests*. Point the BlackBerry RDP client at 720×720 and the host spins up a session that exact size, so apps land framed instead of a giant desktop crammed onto a square and panned. VNC can't do this cleanly. This is why RDP is doubly correct for this build.

---

## 5. The 720×720 rule (non-negotiable)

Do **not** mirror the host's full desktop onto the Classic. Run a desktop **session sized to ~720×720** (RDP does this when the client asks for it; on Linux, `xrdp` session geometry; on Windows, the client-requested size is honored automatically). Get this wrong and modern sites spilling off three edges will feel exactly as sloppy as sir is trying to avoid. Get it right and it reads as a product.

---

## 6. The app — two modes, and the app *is* the switch

The native Cascades launcher is the whole experience. Its home screen is a tile launcher.

- **Offline mode** — falls back to native BB10. Email, keyboard, contacts, calendar, notes — the genuinely good, already-working part of this phone. Untouched, no rebuild.
- **Online mode** — wakes the remote-desktop client, finds the host over Tailscale, and the screen becomes a 720×720 window into a full desktop where the internet actually lives. Tiles (Browser / WhatsApp Web / YouTube) drop straight into a maximized session.

The launcher toggles between them. That's the overhaul — one layer above the firmware sir originally imagined, and from the hand it feels identical to a single unified device.

---

## 7. Apps collapse to one browser

WhatsApp Web (pair by QR), Instagram, YouTube — all websites. The entire ambition reduces to **one well-framed browser session** viewed through the Classic. **No Android emulator on the host is needed.** (Emulator is an optional branch only if a true APK-only app ever becomes mandatory — and even then RDP to a Windows host beats VNC.)

---

## 8. Client sourcing — the one genuinely fiddly step (now researched)

A remote-desktop client that runs on BB10 10.3.3 exists. Test in this order — on the **simulator first** (§9), then on real hardware once it's back in hand:

1. **aRDP — iiordanov/remote-desktop-clients (open-source, FreeRDP-based).** The repo explicitly targets *Android **and** BlackBerry 10*. Cleanest to obtain, free, RDP-native, supports custom resolution (set it to 720×720). **Start here.**
2. **Microsoft Remote Desktop (Android), sideloaded as `.bar`.** Documented running excellently on the Passport and Q10 — same Android-runtime generation and same physical-keyboard form factor as the Classic. Proven, but see the keyboard warning below.
3. **Splashtop (native BB10, non-Android port) — fallback only.** Fast, but proprietary protocol requiring its own streamer on the host, which fights our self-hosted Tailscale + RDP plan. Use only if both RDP clients misbehave.

**⚠️ Known risk to design around:** on physical-keyboard BB10 devices, the MS RDP Android client treats a keyboard tap as a *mouse click*, which sabotages typing. This is precisely the problem the native Cascades launcher in Phase 3 must solve with proper key-event mapping. **This specific behavior cannot be validated on the simulator — it only shows up on real physical keys.** Flagged again in §9 and §12.

**Sideload mechanics (all confirmed working for BB10):** `.bar` files pushed via Development Mode using DDPB (Darcy's Deployment tool), Sachesi, the Chrome PlayBook App Manager extension, or Sideload.it (OTA, no PC). Android clients are installed as `.bar` (APK converted/repackaged).

---

## 9. Testing without the physical device — the BB10 Simulator

The phone isn't in hand right now. That doesn't block the project — BlackBerry shipped an official **Device Simulator** for exactly this purpose, and it's a full simulated BB10 OS environment, not a skin: real Cascades runtime, real app installs, real networking.

**What it proves, with no hardware:**
- The Cascades launcher's UI, layout, and 720×720 framing.
- The Offline/Online mode switch and tile navigation.
- aRDP sideloaded into the simulator, connecting over Wi-Fi to the **real host laptop** (never this dev laptop) — i.e. the *entire pipeline end-to-end*, sized correctly, before the phone is back.

**What it cannot prove:** the keyboard-as-mouse-click quirk from §8. That's a physical-hardware input behavior and has to wait for the real Classic. Everything else can be fully validated now.

**Setup:**
1. Install **Momentics IDE** (the BB10 Native SDK's IDE) on this laptop. Check `developer.blackberry.com/native/downloads/` first — BlackBerry's legacy Native SDK downloads may no longer be listed on the live portal at this point; if so, the **Internet Archive mirror** (`archive.org/details/native-SDK-for-blackberry10`) carries the full Momentics IDE + Native SDK installers and is the reliable fallback.
2. During SDK setup, when Momentics offers "No Device," choose it and make sure **"Download the BlackBerry 10 Simulator"** is checked. The Simulator runs in **VMware Player** (free) — install that first if it isn't already on this machine.
3. Boot the simulator. It displays its **own IP address** at the bottom of its window — that's the address Momentics, Telnet, or sideload tools use to talk to it, exactly as they would a real device on the network.
4. Sideload **aRDP** into the running simulator the same way it'll later go onto the real phone (DDPB / Sachesi, pointed at the simulator's IP instead of a device's).
5. Point aRDP at the **host laptop's** Tailscale/local IP, request a 720×720 session, and confirm the desktop appears framed correctly.

That sequence is the real Phase 0 goal restated: prove the full chain works, hardware notwithstanding.

---

## 10. Phased build (in order — skipping ahead is how this gets sloppy)

### Phase 0 — Prove the pipe (simulator-based, no physical phone needed)
- Set up Momentics IDE + Native SDK + Simulator on **this** (dev) laptop (§9).
- Stand up the **host** on the dedicated old laptop — RDP server + 720×720 session, same Wi-Fi.
- Sideload aRDP into the simulator; connect it to the host.
- **Goal:** simulator → host pipeline works end-to-end at 720×720. If this works, the project is viable.

### Phase 0b — Hardware validation (gate before Phase 3 ships)
- Once the Classic is back in hand: repeat the Phase 0 test on the **real device**.
- Specifically check the keyboard-as-click behavior flagged in §8. This is the one thing the simulator can't tell you.

### Phase 1 — Host done properly
- Confirm the dedicated host laptop and its OS (still open — see §13).
- If it runs **Windows Pro** → built-in RDP, simplest path. Otherwise **Linux + `xrdp`**.
- Force a **720×720** session; browser auto-launches the target sites maximized.

### Phase 2 — Tailscale
- Install on the host; set it to **auto-start on boot** (Windows service / `systemd`).
- Add the BlackBerry-side client to the tailnet so it's reachable off-home.
- Optional: configure **Wake-on-LAN** so the laptop can be woken remotely (addresses the "laptop must be awake" limit).

### Phase 3 — Native Cascades launcher
- **BB10 Native SDK / Momentics IDE.** Cascades (QML + C++).
- Build: tile launcher (Browser / WhatsApp / YouTube), Offline/Online switch, RDP session embed-or-invoke, **proper keyboard + trackpad mapping** (solves the Phase 0b typing issue), clean auto-reconnect.
- Test in the simulator continuously; final sign-off needs Phase 0b's real hardware.

---

## 11. Toolchain summary

- **App:** BB10 Native SDK + Momentics IDE (Cascades/QML/C++).
- **Testing without hardware:** BB10 Device Simulator (VMware Player) — see §9.
- **Sideloading:** Development Mode + DDPB / Sachesi / Sideload.it, pushing `.bar` over USB, OTA, or to the simulator's IP.
- **Host:** Windows Pro (built-in RDP) *or* Linux + `xrdp`; **Tailscale** on top.
- **Phase-0 client:** aRDP (open-source) → MS RDP (`.bar`) → Splashtop (fallback).

---

## 12. Conventions

- Source under `O:\coding\BlackBerryBridge\` → `cascades-app\`, `host-setup\`, `docs\`.
- Nothing touches the BlackBerry system partition. Fully reversible at every stage.
- Tailscale auth keys and any credentials stay in env/config — never committed.
- Incremental and reversible; no large rewrites without sir's sign-off.
- **The dev laptop and the host laptop are never the same machine.** Don't let convenience during testing blur this — even the simulator should be pointed at the real (or a placeholder) host, not localhost on the dev machine.

---

## 13. Honest limits (set expectations now)

- **Laptop must be awake and reachable.** BlackBerry-online = host-on. Wake-on-LAN softens this; it doesn't remove it.
- **Video is the soft spot.** Chat, browse, scroll — fine. YouTube at full frame rate over remote desktop on a 720 square *will* stutter. Plan for it.
- **720×720 matching is non-negotiable.** It's the line between "product" and "demo."
- **The simulator can't validate physical keyboard input behavior.** That single check waits for Phase 0b, when the real Classic is back in hand.
- **The host laptop itself is still unspecified** — which physical machine, and its OS, is needed before Phase 1 can be written concretely.

---

## 14. First session deliverable (Claude Code)

1. Walk through Momentics IDE + Native SDK + Simulator install on this laptop, sourcing from the Internet Archive mirror if the live BlackBerry developer portal no longer hosts the legacy downloads.
2. Get the BB10 Simulator booted and reachable, with its IP confirmed.
3. Source and sideload aRDP into the simulator.
4. Provide the minimal host RDP + 720×720 session setup to test against — flag clearly that this needs to run on the dedicated host laptop, not the dev machine, once that machine is named.
5. Stop and report results before Phase 0b / Phase 1.
