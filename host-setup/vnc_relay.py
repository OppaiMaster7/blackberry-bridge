#!/usr/bin/env python3
"""
vnc_relay.py — BlackBerry Bridge TCP relay.

The BB10 simulator reaches the host only at the VMware host-only address
(192.168.94.1). droidVNC-NG runs *inside* the Android emulator, and
`adb forward` only exposes that port on the host loopback (127.0.0.1).

This relay closes the gap: it listens on 0.0.0.0:<LISTEN> (reachable from the
sim as 192.168.94.1:<LISTEN>) and shovels bytes to 127.0.0.1:<TARGET>, where
adb has forwarded the emulator's VNC port.

    BB10 sim  --TCP-->  192.168.94.1:5900 (this relay)
                          --> 127.0.0.1:5901 (adb forward)
                            --> AVD:5900 (droidVNC-NG)

No admin needed (listen port > 1024). Pure stdlib, no screen capture, AV-safe.

Usage:
    python vnc_relay.py [listen_port=5900] [target_port=5901] [target_host=127.0.0.1]
"""
import socket
import sys
import threading

LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5900
TARGET_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 5901
TARGET_HOST = sys.argv[3] if len(sys.argv) > 3 else "127.0.0.1"

# The raw VNC port has NO authentication, so only the BB10 simulator's host-only subnet
# (VMware vmnet) and loopback may use it. Real phones use the browser gateway (which has
# an access code) — never this port.
ALLOWED_PREFIXES = ("127.", "192.168.94.")


def pump(src, dst, tag):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


def handle(client, addr):
    if not addr[0].startswith(ALLOWED_PREFIXES):
        print("[relay] REFUSED %s:%d (not sim subnet/loopback)" % addr, flush=True)
        client.close()
        return
    print("[relay] client %s:%d connected" % addr, flush=True)
    try:
        upstream = socket.create_connection((TARGET_HOST, TARGET_PORT), timeout=10)
    except OSError as e:
        print("[relay] upstream %s:%d unreachable: %s" % (TARGET_HOST, TARGET_PORT, e),
              flush=True)
        client.close()
        return
    # create_connection() leaves its 10s timeout ON the socket: recv() would then raise
    # after any 10s of server silence (static screen!) and tear the session down. This
    # single line was the BlackBerry's connect/drop/reconnect loop. Blocking mode = fixed.
    upstream.settimeout(None)
    upstream.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    client.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    t1 = threading.Thread(target=pump, args=(client, upstream, "c->s"), daemon=True)
    t2 = threading.Thread(target=pump, args=(upstream, client, "s->c"), daemon=True)
    t1.start(); t2.start()
    t1.join(); t2.join()
    client.close(); upstream.close()
    print("[relay] client %s:%d closed" % addr, flush=True)


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", LISTEN_PORT))
    srv.listen(5)
    print("[relay] listening on 0.0.0.0:%d -> %s:%d  (Ctrl+C to stop)"
          % (LISTEN_PORT, TARGET_HOST, TARGET_PORT), flush=True)
    try:
        while True:
            client, addr = srv.accept()
            threading.Thread(target=handle, args=(client, addr), daemon=True).start()
    except KeyboardInterrupt:
        print("\n[relay] stopping", flush=True)
    finally:
        srv.close()


if __name__ == "__main__":
    main()
