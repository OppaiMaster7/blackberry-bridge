#!/usr/bin/env python3
"""
BlackBerry Bridge — host agent.

Runs on the HOST laptop. Two jobs:
  1. Discovery: answers UDP probes from the BlackBerry app so the phone can FIND this
     laptop on the network (the pairing system), replying with the host's name + RDP port.
  2. RDP stand-in: holds TCP 3389 open so the app's LINK check passes until a real RDP
     server is enabled (Windows: enable Remote Desktop; Linux: xrdp).

Run:  python host_agent.py
"""
import socket, threading, platform

DISCOVERY_PORT = 49152
RDP_PORT       = 3389
MAGIC          = b"BRIDGE_DISCOVERY_V1"
HOSTNAME       = platform.node() or "bridge-host"


def discovery_responder():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    s.bind(("0.0.0.0", DISCOVERY_PORT))
    print("discovery: listening on UDP %d" % DISCOVERY_PORT, flush=True)
    while True:
        data, addr = s.recvfrom(1024)
        print("discovery: probe from %s -> %r" % (addr, data[:24]), flush=True)
        if MAGIC in data:
            # ip is left as 0.0.0.0 on purpose: the app uses the datagram's SOURCE address
            # as the real host IP (correct even on multi-homed hosts).
            reply = ("BRIDGE_HOST|%s|0.0.0.0|%d" % (HOSTNAME, RDP_PORT)).encode()
            s.sendto(reply, addr)
            print("discovery: replied '%s' to %s" % (HOSTNAME, addr), flush=True)


def rdp_standin():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", RDP_PORT))
    s.listen(8)
    print("rdp stand-in: listening on TCP %d" % RDP_PORT, flush=True)
    while True:
        c, a = s.accept()
        print("rdp stand-in: connection from %s" % (a,), flush=True)
        c.close()


if __name__ == "__main__":
    print("BlackBerry Bridge host agent — host '%s'" % HOSTNAME, flush=True)
    threading.Thread(target=discovery_responder, daemon=True).start()
    rdp_standin()
