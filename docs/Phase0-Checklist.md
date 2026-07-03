# Phase 0 checklist — "Prove the pipe"

The gate. When every box here is ticked, the simulator → host pipeline works end-to-end at
720×720 and **the project is viable** (brief §10 Phase 0). Work top to bottom.

## A. Dev laptop toolchain — [`Phase0-Install-Guide.md`](Phase0-Install-Guide.md)
- [ ] VMware Player installed and launching.
- [ ] Virtualization (VT-x/AMD-V) enabled in BIOS.
- [ ] Momentics IDE launches (no JVM error).
- [ ] BB10 Native SDK 10.3.1 present in Momentics.
- [ ] BB10 Simulator boots to home screen; its IP is noted.
- [ ] Development Mode ON in the simulator.
- [ ] Momentics connects to the simulator as a target.

## B. RDP client into the simulator — [`../client-sourcing/README.md`](../client-sourcing/README.md)
- [ ] Era-appropriate RDP client obtained (`.bar`, or old APK repackaged).
- [ ] Client installs **and launches** in the simulator.
- [ ] Client exposes a **custom resolution** field; set to **720×720**.

## C. Host appliance — [`../host-setup/`](../host-setup/)
- [ ] Host OS decided (Windows Pro **or** Linux+xrdp). *(Brief §13: host machine still
      unspecified — a placeholder spare machine on the same Wi-Fi is fine for this gate.)*
- [ ] RDP server enabled; firewall open; host LAN IP known.
- [ ] Host account has a password (RDP rejects blank passwords).
- [ ] Browser auto-launches the target site, maximized (optional but nice).

## D. The pipe — end to end
- [ ] Simulator's RDP client connects to the host over **plain Wi-Fi** (no Tailscale yet).
- [ ] Session renders at **exactly 720×720**, framed — not a panned giant desktop.
- [ ] A target site (e.g. WhatsApp Web) is usable through the simulator.

## ✅ Gate
When A–D are all checked: **stop and report** before Phase 0b / Phase 1 (brief §14.5).

## Explicitly NOT in this gate (Phase 0b — needs the real Classic)
- Keyboard-as-mouse-click behavior on physical keys (brief §8/§9/§12). The simulator cannot
  prove it; it waits for the device to come back in hand.
