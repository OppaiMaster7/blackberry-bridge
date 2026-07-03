# Android Mirror — real Android apps on the BlackBerry

This is the content source for BlackBerry Bridge: a real Android phone (emulator) with
internet and the Play Store, whose live screen is mirrored to the BlackBerry Classic via the
VNC client we already built.

```
BlackBerry Classic / BB10 sim                Laptop (host)
┌───────────────────────────┐     VNC      ┌──────────────────────────────────────────┐
│ BridgeLauncher (VncClient) │ ───────────► │ 192.168.94.1:5900  vnc_relay.py          │
│  LAUNCH MIRROR             │              │        │                                  │
└───────────────────────────┘              │        ▼  127.0.0.1:5901 (adb forward)    │
                                           │   Android emulator "BridgePhone"          │
                                           │   droidVNC-NG :5900  (screen capture)     │
                                           │   → Instagram / WhatsApp / Chrome …       │
                                           └──────────────────────────────────────────┘
```

## Status: WORKING (proven end-to-end)

- **Android source** — AVD `BridgePhone`, Android 14, **Google Play** image, x86_64,
  WHPX-accelerated (boots ~80 s). Internet + DNS confirmed.
- **droidVNC-NG v2.20.0** captures the screen and serves VNC on guest port 5900.
- **Our `VncClient` works unchanged** — droidVNC offers security type *None* (1) and honours
  *RAW* encoding, which is exactly what the client speaks. No client code changes needed.
- **Proof:** `docs/android-mirror-via-pipeline.png` is the real Android screen decoded through
  the **exact** client path (RGBX→RGB888→PNG) — i.e. what the BlackBerry's ImageView renders.

## Bring it all up (one command, durable + self-healing)

```powershell
powershell -ExecutionPolicy Bypass -File host-setup\start_android_source.ps1
```

Boots the emulator (if needed), grants droidVNC's permissions, starts its server, sets up
`adb forward`, verifies the VNC handshake actually serves a frame (retries if the cold-boot
screen-capture grant races), and launches the relay — all detached so it survives the shell.

Then **on the BlackBerry: tap LAUNCH MIRROR** (host is auto-paired as `192.168.94.1`, port 5900).

## droidVNC-NG configuration that matters (learned the hard way)

All set automatically by the start script via `adb`:
1. `pm grant … POST_NOTIFICATIONS` — foreground-service notification (Android 13+).
2. `appops set … PROJECT_MEDIA allow` — pre-authorises MediaProjection so the screen-cast
   consent dialog is skipped. **Must be in place before the server starts**, or Screen
   Capturing shows DENIED and the server serves the RFB version then drops every client.
3. `settings put secure enabled_accessibility_services …/.InputService` (+ `accessibility_enabled 1`)
   — **critical for stability.** Without it droidVNC's native code hits a NullPointerException
   in `InputService.removeClient` and **drops the client after ~2 frames**. With it, the session
   is stable (verified: 32 frames, no drop) and you also get input injection.
4. The server is started from the app's **START button** (the Intent API needs the app's secret
   access key; the UI button does not).

droidVNC reports the framebuffer as **411×914** (its Scaling slider shrinks the 1080×2400
screen — good: lighter frames for the ~3 fps BlackBerry link).

## Two things that still need YOU

1. **Sign in to Google / install the apps.** The emulator has the Play Store but no account.
   Open the emulator window, sign in, install Instagram + WhatsApp. (The mirror shows whatever
   is on the Android screen, so this is a one-time content step.)

2. **The final LAUNCH MIRROR tap.** Two host-side limits block automating it:
   - **Smart App Control is ON (enforcement)** and blocks the unsigned 2014 BlackBerry
     compiler (`qcc.exe`, CodeIntegrity policy). So the BB app **cannot be rebuilt** right now —
     e.g. to make it auto-connect on launch. Turning SAC off (Settings ▸ Privacy & security ▸
     Windows Security ▸ App & browser control ▸ Smart App Control) is **irreversible** and a
     security trade-off — your call.
   - **Synthetic mouse input doesn't reliably reach the VMware guest**, so the tap can't be
     scripted from the host. A real mouse click on the running sim works fine.

   So: with the source live and the app showing **LINK ONLINE**, one physical click on
   **LAUNCH MIRROR** shows the live Android screen on the BlackBerry.

## Files

- `host-setup/start_android_source.ps1` — bring up emulator + droidVNC + forward + relay.
- `host-setup/vnc_relay.py` — `0.0.0.0:5900 → 127.0.0.1:5901` bridge (sim can't reach loopback).
- `host-setup/droidvnc-ng-2.20.0.apk` — the Android VNC server (installed in the AVD).
- `docs/android-mirror-via-pipeline.png` — proof: real Android via the exact client pipeline.
