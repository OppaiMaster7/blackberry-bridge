# BlackBerry Bridge — Install Guide (real BB10 phone + any Windows laptop)

Turn a BlackBerry Classic (or any BB10 phone) into a usable 2026 internet device.
The laptop runs a real Android phone (emulator with Google Play — Instagram, WhatsApp,
Chrome…), and the BlackBerry shows and touch-controls it **through its built-in
Browser** — nothing is installed or modified on the BlackBerry.

> Why the browser? BlackBerry shut down its app-signing servers in 2022, so real BB10
> phones can no longer install homemade apps (a microSD card can't install apps either —
> it's only storage). The browser needs no install and no signing. Zero risk to the phone.

```
  BlackBerry (BB10)                              Windows laptop (8 GB RAM is fine)
  ┌──────────────────────┐    same Wi-Fi     ┌──────────────────────────────────────┐
  │ Browser →            │ ◄───────────────► │ Android 14 emulator (Google Play)     │
  │ http://<laptop>:8080 │      HTTP         │ droidVNC-NG + bridge services         │
  │ (live screen + touch)│                   │ (all auto-started, self-healing)      │
  └──────────────────────┘                   └──────────────────────────────────────┘
```

---

## ONE-TIME SETUP — laptop (≈15 min, needs internet)

1. Copy this whole project folder onto the laptop (USB stick is fine).
2. **Double-click `host-setup\Install-BlackBerryBridge.cmd`** → click **Yes** at the
   admin prompt. It downloads and configures everything by itself:
   - Python + the bridge services
   - Android emulator + Android 14 with Google Play (the big download, ~1.5 GB)
   - droidVNC-NG (screen capture + touch injection), fully permissioned
   - a **720×720 square** Android screen so it fills the BlackBerry exactly
   - firewall rule so the phone can connect
   - a **START BRIDGE** shortcut on the Desktop + auto-start at login
3. When it finishes: in the emulator window, **sign into Google Play** and install
   Instagram / WhatsApp / whatever the phone should run (one-time).

## ONE-TIME SETUP — BlackBerry

Nothing to install. Just make sure it's on the **same Wi-Fi network** as the laptop.
(No Wi-Fi around? Turn on the laptop's mobile **hotspot** — Settings ▸ Network ▸ Mobile
hotspot — and connect the BlackBerry to that.)

## OPTIONAL — use it from ANYWHERE (not just home Wi-Fi)

Want the phone to reach the home laptop over mobile data / any network? Double-click
**`ENABLE-REMOTE.cmd`** once and follow **[docs/REMOTE-ACCESS.md](docs/REMOTE-ACCESS.md)**.
It publishes the mirror at a stable public HTTPS address via Tailscale (free). One thing to
confirm on the actual phone: that the old browser accepts the HTTPS certificate — the doc
covers a plain-HTTP fallback if it doesn't.

---

## DAILY USE (the whole demo)

1. Laptop: double-click **START BRIDGE** (Desktop). Wait for the green box — it prints
   the address **including a 6-digit access code**, e.g.
   `http://192.168.1.150:8080/?k=483920`.
2. BlackBerry: open the **Browser**, type that exact address (code included), press Go.
3. The live Android screen appears. **Touch it to control Android** — tap icons, scroll
   feeds, type on WhatsApp. The Android BACK/HOME buttons are at the bottom of the
   mirrored screen. A tiny fps counter sits in the top-right corner.
4. **Tap the little "FULL" button** (top-left) once to go fullscreen — this hides the
   browser's address bar so the mirror uses the whole screen. (If the BlackBerry browser
   doesn't support fullscreen, just scroll the page up one notch to push the bar off.)

Bookmark the address on the BlackBerry the first time (Browser menu ▸ Add to Home
Screen) — after that it's literally two taps to "boot the phone".

**Sound:** Instagram/WhatsApp/video audio plays out of the **laptop** speakers (the phone
is only the screen + touch). Only droidVNC's own connect-notification is silenced.

**Speed:** the mirror runs about **9–11 frames/second** while things are moving and snaps
instantly when you tap — smooth enough for scrolling feeds and chatting. That rate is the
ceiling of the Android screen-capture on a laptop; it isn't a network problem, so a faster
Wi-Fi won't change it. It uses almost no bandwidth when the screen is still.

**Security:** without the 6-digit `?k=` code, anyone hitting the address gets a
"WRONG OR MISSING ACCESS CODE" page — they can neither see nor touch the phone. The code
lives in `host-setup\bridge_access_key.txt` (delete it to get a fresh one). The raw VNC
port only accepts the simulator's private subnet, never the Wi-Fi. For anything beyond a
home/demo network, prefer the laptop's own hotspot: then the only devices on the network
are yours.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Browser says "cannot connect" | Same Wi-Fi? Run START BRIDGE again (it repairs everything). Re-check the IP it prints — home routers change it sometimes. |
| Black / frozen image | START BRIDGE again — the supervisor also self-heals within ~90 s. |
| Mirror shows the Android lock screen | Click into the emulator window on the laptop and unlock once. |
| Slow / choppy | Keep the laptop on power, close heavy programs (8 GB is enough but not for Chrome-with-60-tabs at the same time). ~9–11 fps is normal and expected. |
| Browser bar covers part of the screen | Tap the **FULL** button (top-left), or scroll the page up once. |
| No sound | Sound comes from the **laptop** speakers, not the phone — check the laptop volume. |
| No Instagram/WhatsApp in the mirror | Sign into Google Play in the emulator window and install them. |

---

## For the developer laptop only (simulator demo)

The original BB10 **app** (auto-pairing + auto-launching native mirror) still runs on the
BB10 *simulator*: `START-DEMO.cmd` brings up Android + the simulator VM + the app and
prints a PASS/FAIL health check. Rebuild notes: `docs\SAFE-BUILD.md` (currently
compiler-blocked; QML-only updates work via the recovered-binary repackage described there).
