# cascades-app — the native BB10 launcher (Phase 3, not started)

This will hold the native **Cascades** application (QML + C++, built in Momentics) that is
the whole user-facing experience. **Do not start it until Phase 0 proves the pipe** (brief
§10 — skipping ahead is how this gets sloppy).

## What it must do (brief §6, §7, §10 Phase 3)

- **Tile launcher** home screen, framed for **720×720**: Browser / WhatsApp Web / YouTube.
- **Offline/Online switch** — the app *is* the switch:
  - *Offline* → native BB10 (email, keyboard, contacts, calendar, notes). Untouched.
  - *Online* → wake the RDP client, find the host over Tailscale, drop into a maximized
    720×720 session.
- **Proper keyboard + trackpad mapping** — the fix for the keyboard-as-mouse-click quirk
  (brief §8). This is the hard part and the reason a thin wrapper isn't enough.
- **Clean auto-reconnect** when the link blinks.

## Why it can't be fully validated yet

The keyboard-as-mouse-click behavior is **physical-hardware-only** (brief §8/§9/§12) — the
simulator can't reproduce it. So the key-event mapping gets designed and unit-tested in the
simulator, but **final sign-off waits for Phase 0b** (real Classic in hand).

## When Phase 3 starts, expected layout

```
cascades-app/
  bar-descriptor.xml      # app manifest (permissions, icon, splash)
  assets/                 # QML + images, 720x720 assets
    main.qml
    tiles/
  src/                    # C++ (app entry, key-event mapping, RDP invoke)
  Makefile / .pro
```

Left intentionally empty until the pipe is proven.
