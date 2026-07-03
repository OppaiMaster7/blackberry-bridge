#!/usr/bin/env python3
"""
bridge_supervisor.py — keep the BlackBerry Bridge host services alive.

Runs the relay, the capture-keepalive and the discovery agent as child processes and
RESTARTS any that exit. This fixes the failure where the keepalive died, droidVNC stopped
capturing, and the BlackBerry app fell into a connect/black-screen loop. One instance only
(a lock port guarantees that): duplicate relays fighting over port 5900 caused random
client drops.

It also re-verifies droidVNC is actually serving frames; if capture has stopped for two
consecutive checks it cycles the droidVNC server (STOP/START via the app UI over adb).
The probe is deliberately infrequent — every probe is a client connect/disconnect that
droidVNC announces with a notification.

Launched by start_android_source.ps1 (detached). One process to rule them all.

    supervisor
      ├─ vnc_relay.py 5900 5901        (0.0.0.0:5900 -> 127.0.0.1:5901)
      ├─ vnc_keepalive.py 5901         (holds droidVNC capture open)
      ├─ host_agent.py                 (UDP discovery + TCP 3389 reachability)
      └─ browser_gateway.py            (HTTP mirror for the real BB10 phone, port 8080)
"""
import os
import re
import subprocess
import sys
import time
import socket
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
PY = sys.executable
SERVICES = {
    "relay":     [PY, os.path.join(HERE, "vnc_relay.py"), "5900", "5901"],
    "keepalive": [PY, os.path.join(HERE, "vnc_keepalive.py"), "5901"],
    "discovery": [PY, os.path.join(HERE, "host_agent.py")],
    "gateway":   [PY, os.path.join(HERE, "browser_gateway.py")],   # BB10 phone browser
}
ADB = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk",
                   "platform-tools", "adb.exe")
PKG = "net.christianbeier.droidvnc_ng"
LOCK_PORT = 49321          # held for the supervisor's lifetime; second instance exits
PROBE_EVERY = 45           # seconds between capture probes (each one "connects a client")
PROBE_FAILS_TO_CYCLE = 2   # consecutive failures before we cycle droidVNC

CREATE_NO_WINDOW = 0x08000000 if os.name == "nt" else 0


def spawn(cmd):
    return subprocess.Popen(cmd, creationflags=CREATE_NO_WINDOW)


def serves_frame(timeout=6):
    """True if droidVNC (via the adb-forwarded port) completes a handshake AND sends a frame."""
    try:
        s = socket.create_connection(("127.0.0.1", 5901), timeout=timeout)
    except OSError:
        return False
    try:
        s.settimeout(timeout)
        def rd(n):
            b = b""
            while len(b) < n:
                c = s.recv(n - len(b))
                if not c:
                    raise EOFError
                b += c
            return b
        if rd(12)[:7] != b"RFB 003":
            return False
        s.sendall(b"RFB 003.008\n"); n = rd(1)[0]; rd(n); s.sendall(bytes([1]))
        if struct.unpack(">I", rd(4))[0] != 0:
            return False
        s.sendall(bytes([1])); w, h = struct.unpack(">HH", rd(4)); rd(16)
        nl = struct.unpack(">I", rd(4))[0]; rd(nl)
        s.sendall(bytes([2, 0, 0, 1, 0, 0, 0, 0]))
        s.sendall(bytes([3, 0, 0, 0, 0, 0, (w >> 8) & 255, w & 255, (h >> 8) & 255, h & 255]))
        if rd(1)[0] != 0:
            return False
        rd(1); nr = struct.unpack(">H", rd(2))[0]
        for _ in range(nr):
            rx, ry, rw, rh = struct.unpack(">HHHH", rd(8)); rd(4); rd(rw * rh * 4)
        return True
    except Exception:
        return False
    finally:
        s.close()


def adb_shell(*a, timeout=15):
    try:
        r = subprocess.run([ADB, "shell", *a], creationflags=CREATE_NO_WINDOW,
                           timeout=timeout, capture_output=True, text=True)
        return r.stdout or ""
    except Exception:
        return ""


def find_vnc_toggle():
    """Locate droidVNC's START/STOP button via uiautomator (no hardcoded coords)."""
    adb_shell("uiautomator", "dump", "/sdcard/bridge_ui.xml")
    xml = adb_shell("cat", "/sdcard/bridge_ui.xml")
    for m in re.finditer(r'text="(START|STOP)".*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml):
        x = (int(m.group(2)) + int(m.group(4))) // 2
        y = (int(m.group(3)) + int(m.group(5))) // 2
        return x, y, m.group(1)
    return None


def cycle_droidvnc():
    """Bring droidVNC capture back by re-granting projection and toggling its server."""
    if not os.path.exists(ADB):
        return
    adb_shell("appops", "set", PKG, "PROJECT_MEDIA", "allow")
    adb_shell("am", "start", "-n", PKG + "/.MainActivity")
    time.sleep(3)
    btn = find_vnc_toggle()
    if btn and btn[2] == "STOP":          # server thinks it's running but capture is dead:
        adb_shell("input", "tap", str(btn[0]), str(btn[1]))   # STOP first
        time.sleep(3)
        btn = find_vnc_toggle()
    if btn:
        adb_shell("input", "tap", str(btn[0]), str(btn[1]))   # START
    else:
        adb_shell("input", "tap", "360", "150")               # last-resort fallback
    time.sleep(4)


def main():
    # single-instance lock: if another supervisor holds the port, quietly exit
    lock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        lock.bind(("127.0.0.1", LOCK_PORT))
        lock.listen(1)
    except OSError:
        print("[supervisor] another instance is running - exiting", flush=True)
        return

    print("[supervisor] starting relay + keepalive + discovery", flush=True)
    procs = {name: spawn(cmd) for name, cmd in SERVICES.items()}
    last_probe = time.time()   # skip the first probe window right after startup
    probe_fails = 0
    while True:
        time.sleep(3)
        for name, cmd in SERVICES.items():
            if procs[name].poll() is not None:
                print("[supervisor] %s died -> restarting" % name, flush=True)
                procs[name] = spawn(cmd)
        now = time.time()
        if now - last_probe > PROBE_EVERY:
            last_probe = now
            if serves_frame():
                probe_fails = 0
            else:
                probe_fails += 1
                print("[supervisor] capture probe failed (%d/%d)"
                      % (probe_fails, PROBE_FAILS_TO_CYCLE), flush=True)
                if probe_fails >= PROBE_FAILS_TO_CYCLE:
                    probe_fails = 0
                    print("[supervisor] capture stalled -> cycling droidVNC", flush=True)
                    cycle_droidvnc()
                    # bounce the keepalive so it re-grabs the freshly-started capture
                    try:
                        procs["keepalive"].terminate()
                    except Exception:
                        pass
                    procs["keepalive"] = spawn(SERVICES["keepalive"])


if __name__ == "__main__":
    main()
