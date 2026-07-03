#!/usr/bin/env python3
"""
browser_gateway.py — BlackBerry Bridge: live mirror for a REAL BB10 phone, zero install.

BlackBerry killed app signing in 2022, so a physical BB10 device can't install homemade
apps anymore. This gateway serves the live Android screen to the phone's BUILT-IN BROWSER
instead:

    BB10 browser --HTTP--> this gateway (0.0.0.0:8080) --VNC--> 127.0.0.1:5901 (droidVNC)

Endpoints (ALL require ?k=<access-code>; wrong/missing -> 403 + rate-limit/ban):
    /            touch-enabled viewer page (ES5 JS, works on the 2014 BB10 WebKit)
    /frame.jpg   latest Android frame as JPEG (clients poll back-to-back = ~10-20 fps)
    /stream      MJPEG push stream (for browsers that support multipart images)
    /touch?x=&y=&d=   normalized 0..1 coords, d=1 down/drag d=0 lift -> VNC PointerEvent
    /status      one-line JSON (frame counter, geometry) — used by the page's watchdog

Safe to expose to the internet (Tailscale Funnel, docs/REMOTE-ACCESS.md): the access code
gates every endpoint and key_allowed() bans a source after repeated wrong codes.
Runs as a service under bridge_supervisor. Needs Pillow (pip install pillow) for JPEG.
"""
import hashlib
import hmac
import io
import json
import os
import re
import secrets
import socket
import struct
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

try:
    from PIL import Image
except ImportError:
    print("[gateway] Pillow missing - run: python -m pip install pillow", flush=True)
    sys.exit(1)

VNC_HOST, VNC_PORT = "127.0.0.1", 5901
HTTP_PORT = 8080
JPEG_QUALITY = 70
PULL_INTERVAL = 0.055   # pace of full-frame pulls (~18/s, the local link's ceiling)

# Access code: without it, anyone on the same Wi-Fi could watch AND control the phone.
# A 6-digit key rides in the URL (?k=...), so on the BlackBerry it's still just "type one
# address". Generated once, persisted next to this script; START-BRIDGE prints the full URL.
KEY_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bridge_access_key.txt")

def load_key():
    try:
        k = open(KEY_FILE).read().strip()
        if k:
            return k
    except OSError:
        pass
    k = "".join(secrets.choice("0123456789") for _ in range(6))
    with open(KEY_FILE, "w") as f:
        f.write(k)
    return k

ACCESS_KEY = load_key()

# Brute-force lockout: with the mirror published to the internet (Tailscale Funnel), a
# 6-digit code must not be guessable. 8 wrong keys from one source = 15-minute ban, and
# every failure costs 0.4s. That caps guessing at ~770 tries/day — the keyspace is 1M.
FAIL_WINDOW, FAIL_LIMIT, BAN_SECS = 600, 8, 900
_fails = {}          # source -> [count, window_start, banned_until]
_fails_lock = threading.Lock()

def key_allowed(source, supplied):
    now = time.time()
    with _fails_lock:
        st = _fails.get(source)
        if st and st[2] > now:
            return False                      # banned; don't even compare
    if hmac.compare_digest(supplied, ACCESS_KEY):
        with _fails_lock:
            _fails.pop(source, None)
        return True
    with _fails_lock:
        st = _fails.get(source)
        if not st or now - st[1] > FAIL_WINDOW:
            st = [0, now, 0]
        st[0] += 1
        if st[0] >= FAIL_LIMIT:
            st[2] = now + BAN_SECS
            print("[gateway] BANNED %s for %ds (too many bad keys)" % (source, BAN_SECS),
                  flush=True)
        _fails[source] = st
    time.sleep(0.4)
    return False


class VncFeed(threading.Thread):
    """Holds one VNC session; keeps the latest frame as a PIL image + JPEG cache."""

    def __init__(self):
        super().__init__(daemon=True)
        self.lock = threading.Condition()
        self.frame_no = 0
        self.reads = 0            # loop iterations (full frames read from droidVNC)
        self.jpeg = None          # encoded latest frame
        self.size = (0, 0)
        self.sock = None
        self.connected = False

    # --- tiny RFB client (security None, RAW, RGBX big-endian) ---
    def _rd(self, n):
        b = b""
        while len(b) < n:
            c = self.sock.recv(n - len(b))
            if not c:
                raise EOFError("vnc closed")
            b += c
        return b

    def _handshake(self):
        s = socket.create_connection((VNC_HOST, VNC_PORT), timeout=8)
        s.settimeout(None)
        s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock = s
        self._rd(12); s.sendall(b"RFB 003.008\n")
        n = self._rd(1)[0]; self._rd(n); s.sendall(bytes([1]))
        if struct.unpack(">I", self._rd(4))[0] != 0:
            raise IOError("vnc auth failed")
        s.sendall(bytes([1]))
        w, h = struct.unpack(">HH", self._rd(4)); self._rd(16)
        nl = struct.unpack(">I", self._rd(4))[0]; self._rd(nl)
        spf = bytearray(20)
        spf[4] = 32; spf[5] = 24; spf[6] = 1; spf[7] = 1
        spf[9] = 255; spf[11] = 255; spf[13] = 255
        spf[14] = 24; spf[15] = 16; spf[16] = 8
        s.sendall(bytes(spf))
        s.sendall(bytes([2, 0, 0, 1, 0, 0, 0, 0]))
        self.size = (w, h)
        self.fb = bytearray(w * h * 4)
        return w, h

    def _req(self, incremental):
        w, h = self.size
        self.sock.sendall(bytes([3, 1 if incremental else 0, 0, 0, 0, 0,
                                 (w >> 8) & 255, w & 255, (h >> 8) & 255, h & 255]))

    def pointer(self, nx, ny, down):
        """Normalized page coords -> fb pixels -> RFB PointerEvent (thread-safe enough:
        sendall on a blocking socket; worst case an OSError kicks the reconnect loop)."""
        if not self.connected:
            return
        w, h = self.size
        if w <= 0:
            return
        nx = min(max(nx, 0.0), 1.0); ny = min(max(ny, 0.0), 1.0)
        x = int(nx * (w - 1) + 0.5); y = int(ny * (h - 1) + 0.5)
        try:
            self.sock.sendall(bytes([5, 1 if down else 0,
                                     (x >> 8) & 255, x & 255, (y >> 8) & 255, y & 255]))
        except OSError:
            pass

    def _publish(self):
        w, h = self.size
        # rawmode RGBX: PIL ignores the 4th byte directly -> no alpha pass, no convert()
        img = Image.frombuffer("RGB", (w, h), bytes(self.fb), "raw", "RGBX", 0, 1)
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=JPEG_QUALITY)
        with self.lock:
            self.jpeg = buf.getvalue()
            self.frame_no += 1
            self.lock.notify_all()

    def wait_jpeg(self, last_no, timeout=10.0):
        """Block until a frame newer than last_no exists; return (no, jpeg)."""
        with self.lock:
            self.lock.wait_for(lambda: self.frame_no > last_no, timeout=timeout)
            return self.frame_no, self.jpeg

    def run(self):
        while True:
            try:
                w, h = self._handshake()
                print("[gateway] VNC up %dx%d" % (w, h), flush=True)
                self.connected = True
                # Paced NON-incremental pulls: droidVNC answers those immediately from its
                # buffer, so the feed runs at ~1/PULL_INTERVAL fps instead of waiting for
                # its (slow, ~10fps) damage tracking. Identical frames are detected by
                # hash and not re-encoded/re-published, so idle stays cheap end-to-end.
                self.sock.settimeout(10.0)   # non-incremental answers come at once;
                last_hash = None             # 10s of silence means the link is dead
                self._req(False)             # prime the first request
                while True:
                    t0 = time.time()
                    got_frame = False
                    while not got_frame:
                        mt = self._rd(1)[0]
                        if mt == 0:
                            self._rd(1)
                            nrects = struct.unpack(">H", self._rd(2))[0]
                            for _ in range(nrects):
                                rx, ry, rw, rh = struct.unpack(">HHHH", self._rd(8))
                                enc = struct.unpack(">i", self._rd(4))[0]
                                if enc != 0:
                                    raise IOError("non-RAW rect")
                                data = self._rd(rw * rh * 4)
                                for row in range(rh):
                                    dst = ((ry + row) * w + rx) * 4
                                    src = row * rw * 4
                                    self.fb[dst:dst + rw * 4] = data[src:src + rw * 4]
                            got_frame = True
                        elif mt == 2:
                            pass
                        elif mt == 3:
                            ln = struct.unpack(">I", self._rd(8)[4:8])[0]
                            self._rd(ln)
                        else:
                            raise IOError("msg %d" % mt)
                    # PIPELINE: ask droidVNC for the next frame NOW, so its ~85ms recapture
                    # overlaps our md5+JPEG encode instead of running after it (+~20% fps).
                    self._req(False)
                    self.reads += 1
                    dig = hashlib.md5(self.fb).digest()
                    if dig != last_hash:
                        last_hash = dig
                        self._publish()
                    spare = PULL_INTERVAL - (time.time() - t0)
                    if spare > 0:
                        time.sleep(spare)
            except Exception as e:
                self.connected = False
                print("[gateway] VNC reconnecting (%s)" % e, flush=True)
                try:
                    if self.sock:
                        self.sock.close()
                except OSError:
                    pass
                time.sleep(1.5)


FEED = VncFeed()

PAGE = """<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<title>Bridge</title>
<style>
  html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden;
            -webkit-user-select:none;-webkit-touch-callout:none}
  #wrap{position:absolute;top:0;left:0;right:0;bottom:0;text-align:center}
  #scr{display:block;margin:0 auto}
  #hud{position:absolute;top:4px;right:6px;color:#39d353;font:11px monospace;opacity:.7}
  #fsb{position:absolute;top:2px;left:4px;color:#fff;background:rgba(30,40,55,.55);
       font:bold 13px monospace;padding:5px 10px;border-radius:4px;opacity:.85}
</style></head>
<body>
<div id="wrap"><img id="scr"><div id="hud">...</div>
<div id="fsb">FULL</div></div>
<script type="text/javascript">
var KEY = '%KEY%';
var img = document.getElementById('scr');
var hud = document.getElementById('hud');
var fsb = document.getElementById('fsb');
var frames = 0, t0 = new Date().getTime();

// --- fit: size the square mirror to whatever space the browser chrome leaves us,
//     letterboxed instead of cropped; re-fit on resize/rotation/fullscreen ---
function fit() {
  var w = window.innerWidth  || document.documentElement.clientWidth;
  var h = window.innerHeight || document.documentElement.clientHeight;
  var side = Math.min(w, h);
  img.style.width  = side + 'px';
  img.style.height = side + 'px';
  img.style.marginTop = Math.max(0, (h - side) / 2) + 'px';
}
window.onresize = fit;
fit(); setTimeout(fit, 400);

// --- fullscreen: removes the browser bar entirely where the API exists ---
function goFull() {
  var el = document.documentElement;
  var f = el.requestFullscreen || el.webkitRequestFullscreen || el.webkitRequestFullScreen
       || el.mozRequestFullScreen;
  if (f) { try { f.call(el); } catch (e) {} }
  setTimeout(fit, 300); setTimeout(fit, 900);
}
fsb.onclick = goFull;
fsb.addEventListener('touchend', function (e) { goFull(); e.preventDefault(); }, false);
function fsChange() {
  var on = document.fullscreenElement || document.webkitFullscreenElement
        || document.webkitCurrentFullScreenElement;
  fsb.style.display = on ? 'none' : 'block';
  fit();
}
document.addEventListener('fullscreenchange', fsChange, false);
document.addEventListener('webkitfullscreenchange', fsChange, false);

// --- video ---
// PRIMARY: MJPEG stream over ONE persistent connection. Crucial over the remote
//   (Tailscale) link: polling paid a full round-trip PER FRAME (~0.5s = ~2 fps);
//   the stream pays latency once, then frames flow at the source's real rate.
// FALLBACK: if a browser can't render multipart/x-mixed-replace (no first frame
//   within 4s, or the connection errors), drop to back-to-back JPEG polling.
var mode = 'stream', gotFirst = false;
function tick() {
  frames++;
  var dt = (new Date().getTime() - t0) / 1000;
  if (dt > 2) { hud.innerHTML = Math.round(frames / dt) + ' fps'; frames = 0; t0 = new Date().getTime(); }
}
function pollNext() { img.src = '/frame.jpg?k=' + KEY + '&t=' + new Date().getTime(); }
function startPoll() {
  if (mode === 'poll') return;
  mode = 'poll';
  img.onload  = function () { tick(); setTimeout(pollNext, 10); };
  img.onerror = function () { hud.innerHTML = 'link...'; setTimeout(pollNext, 800); };
  pollNext();
}
function startStream() {
  mode = 'stream'; gotFirst = false;
  img.onload  = function () { gotFirst = true; tick(); };
  img.onerror = function () { if (mode === 'stream') startPoll(); };
  img.src = '/stream?k=' + KEY;
  // if the stream never paints a first frame, the browser doesn't support it -> poll
  setTimeout(function () { if (mode === 'stream' && !gotFirst) startPoll(); }, 4000);
}
startStream();

// --- touch: forward to the gateway as normalized coords ---
var lastSend = 0;
function send(x, y, d, force) {
  var now = new Date().getTime();
  if (!force && now - lastSend < 40) return;   // throttle drags
  lastSend = now;
  var r = new XMLHttpRequest();
  r.open('GET', '/touch?k=' + KEY + '&x=' + x.toFixed(4) + '&y=' + y.toFixed(4) + '&d=' + d, true);
  r.send();
}
function norm(ev) {
  var t = ev.touches && ev.touches.length ? ev.touches[0] : ev;
  var rect = img.getBoundingClientRect ? img.getBoundingClientRect()
                                       : {left: img.offsetLeft, top: img.offsetTop,
                                          width: img.offsetWidth, height: img.offsetHeight};
  var w = rect.width || img.offsetWidth, h = rect.height || img.offsetHeight;
  return {x: (t.clientX - rect.left) / w, y: (t.clientY - rect.top) / h};
}
function onDown(ev) { var p = norm(ev); send(p.x, p.y, 1, true); ev.preventDefault(); return false; }
function onMove(ev) { var p = norm(ev); send(p.x, p.y, 1, false); ev.preventDefault(); return false; }
function onUp(ev)   { var p = norm(ev.changedTouches && ev.changedTouches.length ? ev.changedTouches[0] : ev);
                      send(p.x, p.y, 0, true); ev.preventDefault(); return false; }
if ('ontouchstart' in window) {
  img.addEventListener('touchstart', onDown, false);
  img.addEventListener('touchmove',  onMove, false);
  img.addEventListener('touchend',   onUp,   false);
} else {
  var mdown = false;
  img.onmousedown = function (e) { mdown = true;  return onDown(e); };
  img.onmousemove = function (e) { if (mdown) return onMove(e); };
  img.onmouseup   = function (e) { mdown = false; return onUp(e); };
}
</script>
</body></html>"""


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):       # quiet: /frame.jpg would spam
        pass

    def _send(self, code, ctype, body, extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        u = urlparse(self.path)
        path = u.path
        q = parse_qs(u.query)
        supplied = (q.get("k") or [""])[0]
        # behind Tailscale Funnel the TCP peer is local; the real client is in X-Forwarded-For
        xff = (self.headers.get("X-Forwarded-For") or "").split(",")[0].strip()
        source = xff or self.client_address[0]
        if not key_allowed(source, supplied):
            self._send(403, "text/html; charset=utf-8",
                       (b"<html><body style='background:#000;color:#f85149;"
                        b"font-family:monospace;text-align:center;padding-top:40%%'>"
                        b"WRONG OR MISSING ACCESS CODE<br>ask for the bridge address"
                        b"</body></html>"))
            return
        if path == "/":
            self._send(200, "text/html; charset=utf-8",
                       PAGE.replace("%KEY%", ACCESS_KEY).encode())
        elif path == "/frame.jpg":
            # long-poll: prefer a frame NEWER than now (instant when the screen moves),
            # otherwise re-send the current one after a short wait (cheap when idle)
            with FEED.lock:
                cur = FEED.frame_no
            no, jpeg = FEED.wait_jpeg(cur, timeout=0.5)
            if jpeg is None:
                self._send(503, "text/plain", b"no frame yet")
            else:
                self._send(200, "image/jpeg", jpeg)
        elif path == "/stream":
            # MJPEG push for engines that support multipart images
            self.send_response(200)
            self.send_header("Content-Type",
                             "multipart/x-mixed-replace; boundary=bridgeframe")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            last = 0
            try:
                while True:
                    last, jpeg = FEED.wait_jpeg(last, timeout=10.0)
                    if jpeg is None:
                        continue
                    self.wfile.write(b"--bridgeframe\r\nContent-Type: image/jpeg\r\n"
                                     b"Content-Length: " + str(len(jpeg)).encode()
                                     + b"\r\n\r\n" + jpeg + b"\r\n")
            except OSError:
                return
        elif path == "/touch":
            q = dict(re.findall(r"([a-z]+)=([-0-9.]+)", self.path))
            try:
                FEED.pointer(float(q.get("x", 0)), float(q.get("y", 0)),
                             q.get("d", "0") == "1")
                self._send(200, "text/plain", b"ok")
            except ValueError:
                self._send(400, "text/plain", b"bad")
        elif path == "/status":
            w, h = FEED.size
            body = json.dumps({"connected": FEED.connected, "frame": FEED.frame_no,
                               "reads": FEED.reads, "w": w, "h": h}).encode()
            self._send(200, "application/json", body)
        else:
            self._send(404, "text/plain", b"not found")


def main():
    FEED.start()
    srv = ThreadingHTTPServer(("0.0.0.0", HTTP_PORT), Handler)
    print("[gateway] serving on port %d, access key %s "
          "(BlackBerry opens http://<laptop-ip>:%d/?k=%s)"
          % (HTTP_PORT, ACCESS_KEY, HTTP_PORT, ACCESS_KEY), flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
