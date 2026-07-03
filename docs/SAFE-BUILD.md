# Safe build — rebuild the BlackBerry app without weakening your laptop

> **STATUS 2026-07-02: the Sandbox route is DEAD.** A Windows update now enforces an
> Application Control (Device Guard) policy *inside* Windows Sandbox too — the 2014
> compiler is blocked there even when copied to the sandbox's own disk (verified). The
> host is still blocked by Smart App Control as before. Until a new build environment
> exists, the app is updated WITHOUT a compiler:
>
> 1. QML/asset changes need no compiling. The July-1 compiled binary was recovered off
>    the simulator (`BarDeploy.jar -getFile app/native/BridgeLauncher ...`) and lives at
>    `cascades-app/BridgeLauncher/BridgeLauncher.recovered` — keep this file safe!
> 2. Repackage: copy `BridgeLauncher.recovered` -> `BridgeLauncher`, then run the Java
>    packager (java is NOT blocked):
>    `java -cp <libs> com.qnx.bbt.nativepackager.BarNativePackager -devMode -package BridgeLauncher.bar bar-descriptor.xml`
> 3. Deploy as usual with `host-setup\deploy-bar.ps1`.
>
> Pending C++ fixes already written in `src/` (silent link poll, 2s keepalive nudge,
> 30ms frame throttle, C++ auto-start) compile the day a build env exists. Best
> candidate: **WSL + the Linux-host BB NDK** (archive.org "bbdevtools" item) — WSL has
> no Application Control. Needs `wsl --install` (admin + reboot).

Smart App Control (SAC) blocks the unsigned 2014 BlackBerry compiler on your real Windows.
Rather than turn SAC off (irreversible), we build inside **Windows Sandbox** — a disposable,
throwaway Windows that Microsoft builds into Win11 Pro. It has no SAC, so the compiler runs
there; nothing it does touches your real system, and your SAC/Defender/etc. stay fully on.

Deploying the built app is **not** blocked (only the compiler is), so that happens on the host.

## One-time: enable Windows Sandbox

In an **Administrator** PowerShell:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All
```

Then **reboot**. (It needs virtualization, which this laptop already has.)

## Each time you want to rebuild the BB app

1. **Double-click** `host-setup\build-vm\BridgeBuild.wsb`.
   Windows Sandbox opens, maps in the toolchain + source (read-only) and the project folder
   (read-write), and automatically runs the build. When it prints **BUILD OK**, the freshly
   compiled `BridgeLauncher.bar` is already back in your project folder.
2. Close the Sandbox (it discards everything else).
3. On the host, deploy it to the simulator:
   ```powershell
   powershell -ExecutionPolicy Bypass -File host-setup\deploy-bar.ps1
   ```

That's it — the rebuilt app (square fit + **tap/scroll to control Android** + auto-reconnect)
is now on the BlackBerry.

## What the rebuild adds (code already written, waiting to compile)

- **Touch passthrough** — `VncClient::pointer()` sends VNC PointerEvents; `main.qml` forwards
  taps/drags on the feed. droidVNC-NG injects them into Android via its accessibility service
  (already enabled). So you tap icons, scroll feeds, type — from the BlackBerry.
- **Auto-reconnect** — if the link blips or a static screen idle-drops, the client retries the
  same host after ~1.5 s instead of sitting on a black screen.
- (Square 720×720 fit is already handled on the Android side via `wm size 720x720`.)

## If Windows Sandbox won't enable

Fallback: a small Win10 VM in VMware (SAC is off there too) — copy `C:\bbndk` in, run the same
`build-bar.ps1`. Heavier on RAM; use it only if Sandbox is unavailable.
