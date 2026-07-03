#!/usr/bin/env python3
"""One-shot probe: exit 0 if the VNC path serves a frame end-to-end (via the relay on
127.0.0.1:5900 — the exact route the BlackBerry uses), exit 1 otherwise."""
import socket, struct, sys

def rd(s, n):
    b = b""
    while len(b) < n:
        c = s.recv(n - len(b))
        if not c:
            raise EOFError
        b += c
    return b

try:
    s = socket.create_connection(("127.0.0.1", 5900), timeout=6)
    s.settimeout(6)
    if rd(s, 12)[:7] != b"RFB 003":
        sys.exit(1)
    s.sendall(b"RFB 003.008\n")
    n = rd(s, 1)[0]; rd(s, n); s.sendall(bytes([1]))
    if struct.unpack(">I", rd(s, 4))[0] != 0:
        sys.exit(1)
    s.sendall(bytes([1]))
    w, h = struct.unpack(">HH", rd(s, 4)); rd(s, 16)
    nl = struct.unpack(">I", rd(s, 4))[0]; rd(s, nl)
    spf = bytearray(20); spf[4]=32; spf[5]=24; spf[6]=1; spf[7]=1
    spf[9]=255; spf[11]=255; spf[13]=255; spf[14]=24; spf[15]=16; spf[16]=8
    s.sendall(bytes(spf)); s.sendall(bytes([2,0,0,1,0,0,0,0]))
    s.sendall(bytes([3,0,0,0,0,0,(w>>8)&255,w&255,(h>>8)&255,h&255]))
    if rd(s, 1)[0] != 0:
        sys.exit(1)
    rd(s, 1); nr = struct.unpack(">H", rd(s, 2))[0]
    for _ in range(nr):
        rx, ry, rw, rh = struct.unpack(">HHHH", rd(s, 8)); rd(s, 4); rd(s, rw*rh*4)
    print("OK %dx%d" % (w, h))
    sys.exit(0)
except Exception as e:
    print("FAIL %s" % e)
    sys.exit(1)
