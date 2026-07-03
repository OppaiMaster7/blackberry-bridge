# Phase 0 — Install Guide (dev laptop)

Goal: get **Momentics IDE + BB10 Native SDK + BB10 Simulator** running on *this* dev
laptop, so the Cascades launcher and the full RDP pipe can be proven before the physical
Classic is back in hand.

> **What I (Claude) can and can't do here.** I can verify download sources, write the
> exact steps and config, and prep every command. The actual installs are **GUI installers
> and large downloads you run yourself** — I can't click through a VMware/Momentics wizard.
> Run the steps below; paste any error back and I'll unblock it.

---

## Already downloaded for you → `../sdk-downloads/`

Claude fetched these from archive.org (verified by exact byte size — see
`../sdk-downloads/fetch.sh` and `download.log`). You do **not** need to touch the dead
BlackBerry servers:

| Local file | What it is | Size |
|---|---|---|
| `momentics-2.1.2.win32.x86_64.setup.exe` | Momentics IDE 2.1.2 (Win x64) | ~373 MB |
| `bbndk.win32.libraries.10.3.1.995.zip` | Native SDK — libraries | ~1.6 GB |
| `bbndk.win32.tools.10.3.1.12.zip` | Native SDK — tools/compiler | ~291 MB |
| `bbndk.win32.documents.10.3.1.995.zip` | Native SDK — docs | ~31 MB |
| `bbndk.win32.cshost.10.3.1.995.zip` | Native SDK — code-sign host | ~20 MB |
| `bbndk.win32.samples.10.3.1.995.zip` | Native SDK — samples | small |
| `bbndk.win32.qconfigmk.10.3.1.995.zip` | Native SDK — qconfig | small |
| `BB10-Simulator-10.3.2.281-Win.exe` | **BB10 Simulator 10.3.2.281** (self-contained VMware image installer) | ~1.35 GB |

> Simulator is **10.3.2.281** — the closest archived build to the device's 10.3.3 (no 10.3.3
> simulator was ever published). A 10.3.1-SDK app runs fine on it.

## Verified sources (checked 2026-06-28), if you ever need to re-fetch

The live BlackBerry developer portal (`developer.blackberry.com/native/downloads/`) is
effectively dead. The **Internet Archive mirrors** used:

- **Momentics IDE + Native SDK 10.3.1 zips:** <https://archive.org/details/bbdevtools>
- **BB10 Device Simulator images:** <https://archive.org/details/blackberry10-device-simulator>
- **Alternate SDK/IDE mirror:** <https://archive.org/details/native-SDK-for-blackberry10>

### ⚠️ Version-match nuance (not in the brief)

The newest archived SDK is **10.3.1.995**, while the target device runs **10.3.3**. This is
fine: a 10.3.1 Native SDK builds Cascades apps that run on a 10.3.3 device — the OS is
backward-compatible with apps built against the slightly older SDK. Do **not** burn time
hunting for an exact 10.3.3 SDK; it was never published to these mirrors. Build against
10.3.1, target/test on the 10.3.3 device.

---

## Prerequisites on the dev laptop

1. **VMware Player / VMware Workstation Player** (free for non-commercial use). The BB10
   Simulator is a VMware appliance, not an emulator skin — install VMware **first**.
   - Broadcom now hosts the old VMware Player downloads (free, account required), or use a
     trusted archived `VMware-player` build. Confirm it launches before going further.
2. **A 64-bit Windows host with virtualization (VT-x/AMD-V) enabled in BIOS.** The
   simulator won't boot otherwise — check this now, it's the #1 silent failure.
3. **~10–15 GB free disk** for the SDK + simulator image.
4. **Java** — older Momentics builds bundle their own JRE; if the IDE fails to launch with a
   JVM error, that's the thing to fix first.

---

## Install steps

### 1. VMware Player
- Install it, reboot if prompted, confirm it opens to its library screen.
- If "VT-x is disabled" appears at any point → reboot into BIOS/UEFI, enable
  Virtualization Technology, save, retry.

### 2. Momentics IDE
- Run `sdk-downloads/momentics-2.1.2.win32.x86_64.setup.exe`. Accept defaults.
- Launch Momentics. If it prompts to update from BlackBerry's servers, **decline** — those
  servers are dead; we install the SDK offline from local zips (next step).

### 3. Install the Native SDK 10.3.1 offline (from the local zips)
- The `bbndk.win32.*.zip` files in `sdk-downloads/` are the API-level components Momentics
  would normally pull online. Install them as a **local/offline API level**:
  - In Momentics: **Window → Preferences → BlackBerry → API Levels → Add**, then point it at
    the local zips / folder (or use the "install from local" option). If the offline path is
    unclear in your build, **stop and tell me** — the exact menu wording shifts between
    Momentics builds and I'll walk you through your specific one.
- Goal: an installed **API Level 10.3.1** showing in Momentics, usable as a build target.

### 4. Install + boot the Simulator
- Run `sdk-downloads/BB10-Simulator-10.3.2.281-Win.exe`. It's self-contained: it drops the
  VMware appliance and registers it (VMware Player must already be installed — step 1).
- Open the installed simulator's `.vmx` in VMware Player → Play (or launch via the Start-menu
  shortcut the installer creates).
- Let BB10 boot fully. At the **bottom of the simulator window it prints its own IP
  address** — note it. That IP is what Momentics, Telnet, and sideload tools target, exactly
  like a real device on the LAN.
- In the simulator: **Settings → Security and Privacy → Development Mode → ON.** Sideloading
  requires Development Mode, same as real hardware.

### 5. Confirm the toolchain talks to the simulator
- In Momentics: **Add a target** → enter the simulator's IP → it should connect and show
  device info.
- This proves the SDK ↔ simulator link before any sideloading. Stop here and report success
  if you've gotten this far — it's the first real milestone.

---

## Definition of done for this guide

- [ ] VMware Player installed and opening.
- [ ] Momentics IDE launches without a JVM error.
- [ ] 10.3.1 Native SDK present in Momentics.
- [ ] Simulator boots to the BB10 home screen and shows its IP.
- [ ] Development Mode ON in the simulator.
- [ ] Momentics connects to the simulator as a target.

Next: [`../client-sourcing/README.md`](../client-sourcing/README.md) to get aRDP into the
simulator, then [`../host-setup/`](../host-setup/) for something to connect to.

---

### Sources
- <https://archive.org/details/native-SDK-for-blackberry10>
- <https://archive.org/details/bbdevtools>
