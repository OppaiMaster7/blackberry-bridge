#!/usr/bin/env python3
"""
vnc_keepalive.py — keep droidVNC-NG capturing.

droidVNC-NG starts screen capture when the first VNC client connects and STOPS it when the
last client disconnects — and on Android 14 it does not reliably restart capture for the next
client. So if the BlackBerry link ever blips, capture dies and every reconnect finds a black
screen ("resetting over and over").

Fix: hold one always-on client here. As long as this stays connected, droidVNC keeps capturing,
so the BlackBerry can drop and reconnect freely. This client just requests a frame every couple
of seconds and discards it. It reconnects itself if dropped.

Connects to 127.0.0.1:<port> (the adb-forwarded droidVNC port, default 5901).

Usage: python vnc_keepalive.py [port=5901]
"""
import socket, struct, sys, time

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5901

def rd(s, n):
    b = b""
    while len(b) < n:
        c = s.recv(n - len(b))
        if not c:
            raise EOFError
        b += c
    return b

def session():
    s = socket.create_connection(("127.0.0.1", PORT), timeout=8)
    s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    if rd(s, 12)[:7] != b"RFB 003":
        raise IOError("bad version")
    s.sendall(b"RFB 003.008\n")
    n = rd(s, 1)[0]; rd(s, n)
    s.sendall(bytes([1]))                       # security None
    if struct.unpack(">I", rd(s, 4))[0] != 0:
        raise IOError("auth")
    s.sendall(bytes([1]))                        # ClientInit
    w, h = struct.unpack(">HH", rd(s, 4)); rd(s, 16)
    nl = struct.unpack(">I", rd(s, 4))[0]; rd(s, nl)
    # minimal pixel format is fine; ask for RAW
    s.sendall(bytes([2, 0, 0, 1, 0, 0, 0, 0]))
    print("[keepalive] holding capture open (%dx%d)" % (w, h), flush=True)
    incremental = 0
    last = 0.0
    while True:
        now = time.time()
        if now - last > 2.0:                     # nudge a frame every 2s
            s.sendall(bytes([3, incremental, 0, 0, 0, 0,
                             (w >> 8) & 255, w & 255, (h >> 8) & 255, h & 255]))
            incremental = 1
            last = now
        s.settimeout(3.0)
        try:
            mt = rd(s, 1)[0]
        except socket.timeout:
            continue
        if mt == 0:                              # FramebufferUpdate -> drain & discard
            rd(s, 1); nr = struct.unpack(">H", rd(s, 2))[0]
            for _ in range(nr):
                rx, ry, rw, rh = struct.unpack(">HHHH", rd(s, 8))
                enc = struct.unpack(">i", rd(s, 4))[0]
                if enc == 0:
                    rd(s, rw * rh * 4)
        elif mt == 2:
            pass
        elif mt == 3:
            ln = struct.unpack(">I", rd(s, 8)[4:8])[0]; rd(s, ln)

def main():
    while True:
        try:
            session()
        except Exception as e:
            print("[keepalive] reconnecting (%s)" % e, flush=True)
        time.sleep(1.5)

if __name__ == "__main__":
    main()
