#!/usr/bin/env python3
"""
BlackBerry Bridge — minimal VNC (RFB 3.8) TEST server.

Serves a SYNTHETIC animated framebuffer (a gradient + a moving white square) over the VNC
protocol on TCP 5900. It does NOT capture the screen, so it is AV-safe and needs no installs.
Purpose: prove the BlackBerry app's VNC client end-to-end. The real content later comes from
droidVNC-NG running inside the Android emulator (a standard RFB server the same client speaks to).

Subset implemented: security 'None', RAW encoding, pixel format R,G,B,X (big-endian shifts).
Run:  python vnc_test_server.py
"""
import socket, struct, threading, math, time

W, H = 480, 480
PORT = 5900

# precompute a static gradient base (bytes: R,G,B,X per pixel)
_base = bytearray(W * H * 4)
for y in range(H):
    for x in range(W):
        i = (y * W + x) * 4
        _base[i]     = 220              # R  (solid red field for an unmistakable test)
        _base[i + 1] = (y * 120) // H   # G  (slight vertical gradient so it's clearly an image)
        _base[i + 2] = (x * 120) // W   # B
        _base[i + 3] = 255              # X / alpha = opaque
_BASE = bytes(_base)

def build_frame(n):
    buf = bytearray(_BASE)
    cx = int(W / 2 + (W / 3) * math.cos(n * 0.18))
    cy = int(H / 2 + (H / 3) * math.sin(n * 0.18))
    s = 45
    for yy in range(max(0, cy - s), min(H, cy + s)):
        base = yy * W
        for xx in range(max(0, cx - s), min(W, cx + s)):
            i = (base + xx) * 4
            buf[i] = 255; buf[i + 1] = 255; buf[i + 2] = 255; buf[i + 3] = 255
    return bytes(buf)

def handle(conn, addr):
    print("vnc: client", addr, flush=True)
    f = conn.makefile("rwb")
    try:
        f.write(b"RFB 003.008\n"); f.flush()
        f.read(12)                                   # client version
        f.write(struct.pack(">BB", 1, 1)); f.flush() # 1 sec type: None(1)
        f.read(1)                                    # chosen sec type
        f.write(struct.pack(">I", 0)); f.flush()     # SecurityResult OK
        f.read(1)                                    # ClientInit (shared)
        pixfmt = struct.pack(">BBBBHHHBBB3x", 32, 24, 1, 1, 255, 255, 255, 24, 16, 8)
        name = b"BridgeVNCTest"
        f.write(struct.pack(">HH", W, H) + pixfmt + struct.pack(">I", len(name)) + name)
        f.flush()
        n = 0
        while True:
            t = f.read(1)
            if not t:
                break
            mt = t[0]
            if mt == 0:        # SetPixelFormat
                f.read(19)
            elif mt == 2:      # SetEncodings
                f.read(1)
                cnt = struct.unpack(">H", f.read(2))[0]
                f.read(cnt * 4)
            elif mt == 3:      # FramebufferUpdateRequest
                f.read(9)
                time.sleep(0.12)
                frame = build_frame(n); n += 1
                hdr = struct.pack(">BxH", 0, 1)                  # type0, pad, 1 rect
                rect = struct.pack(">HHHHi", 0, 0, W, H, 0)      # x,y,w,h, RAW(0)
                f.write(hdr + rect + frame); f.flush()
            elif mt == 4:      # KeyEvent
                f.read(7)
            elif mt == 5:      # PointerEvent
                f.read(5)
            elif mt == 6:      # ClientCutText
                f.read(3); l = struct.unpack(">I", f.read(4))[0]; f.read(l)
            else:
                break
    except Exception as e:
        print("vnc: client gone (%s)" % e, flush=True)
    finally:
        conn.close()

def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", PORT)); s.listen(4)
    print("vnc test server: listening on TCP %d (%dx%d synthetic)" % (PORT, W, H), flush=True)
    while True:
        conn, addr = s.accept()
        threading.Thread(target=handle, args=(conn, addr), daemon=True).start()

if __name__ == "__main__":
    main()
