# Client sourcing — getting an RDP client onto BB10

This is, per the brief's §8, "the one genuinely fiddly step." Research as of **2026-06-28**
shows it's *fiddlier than the brief implies* — read the correction below before downloading
anything.

## The correction (verified 2026-06-28)

The brief says aRDP from `iiordanov/remote-desktop-clients` is "cleanest to obtain... RDP-
native... **Start here.**" Two things are now true that weren't assumed:

1. **The repo no longer ships `.bar` files.** Its GitHub *description* still reads "Clients
   for Android and Blackberry 10," but every release asset is Android `.apk` / `.aab`, and
   the README dropped BB10 entirely. Latest release: **v6.4.5 (2026-06-22)**.
2. **The current APK won't run on the Classic.** The Classic's Android runtime is
   **≈ Android 4.3 Jelly Bean (API 18)**. A 2026 aRDP/FreeRDP APK targets a far newer Android
   and will refuse to install or crash on launch.

So the real task is **"find an era-appropriate (≈2014–2016) RDP client and get it to `.bar`."**

## Source order (revised)

Try in this order, **on the simulator first**, then real hardware in Phase 0b.

### 1. Era-appropriate aRDP `.bar` (best case)
- Look for a prebuilt BB10 `.bar` of aRDP/bVNC from the 2014–2016 BB10 era. Likely homes:
  BlackBerry World archives, CrackBerry forum attachments, archive.org BB10 app collections
  (e.g. <https://archive.org/details/BlackberryOS10apps_open_source_software>).
- If found as a ready `.bar`, this skips all repackaging. **Prefer this.**

### 2. Old aRDP APK → repackage to `.bar`
- Get an aRDP/FreeRDP APK **old enough for Android 4.3** (check `minSdkVersion ≤ 18`).
- Convert with the BB10 runtime packager / `apk2bar` style tooling (the BB10 Android-runtime
  signing+repackage path). The simulator's Android runtime is the test bed.
- Expect signing and runtime-compat fiddliness — this is where time goes.

### 3. Microsoft Remote Desktop (Android) `.bar`
- Documented running well on Passport/Q10 (same runtime generation + physical keyboard).
  Same era-appropriateness rule: an **old** MS RDP APK, repackaged.
- **⚠️ Known risk:** on physical-keyboard BB10 devices the MS RDP Android client treats a
  key tap as a *mouse click*, sabotaging typing. **Cannot be reproduced on the simulator** —
  it only shows on real keys. This is exactly what the Phase 3 native launcher's key-event
  mapping must fix. Flagged in brief §8/§9/§12.

### 4. Splashtop (native BB10) — fallback only
- Fast, but proprietary protocol needing its own streamer on the host, which fights the
  self-hosted Tailscale + RDP plan. Use only if every RDP client misbehaves.

## Sideload mechanics (confirmed for BB10)

Push `.bar` over Development Mode using any of:
- **DDPB** (Darcy's PlayBook/BB10 Deployment tool)
- **Sachesi**
- **Chrome PlayBook App Manager** extension
- **Sideload.it** (OTA, no PC)

For the **simulator**, point the tool at the **simulator's IP** (shown at the bottom of its
VMware window) instead of a USB device. Same flow it'll later use on the real phone.

## Definition of done

- [ ] An RDP client that **installs and launches** in the BB10 simulator.
- [ ] It exposes a **custom resolution** setting (we need exactly **720×720**).
- [ ] It can reach a host by IP and request a session.

> The keyboard-as-mouse-click check is deliberately **not** in this list — it's a Phase 0b
> real-hardware test (brief §8). The simulator cannot prove it.

### Sources
- <https://github.com/iiordanov/remote-desktop-clients> (Android-only releases as of v6.4.5)
- <https://github.com/iiordanov/remote-desktop-clients/releases>
- <https://archive.org/details/BlackberryOS10apps_open_source_software>
