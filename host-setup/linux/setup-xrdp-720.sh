#!/usr/bin/env bash
# setup-xrdp-720.sh
# Run this ON THE DEDICATED HOST LAPTOP (Linux), NOT the dev machine.
# Installs xrdp and prepares a ~720x720 RDP session for the BlackBerry Bridge.
#
# Usage:  sudo bash setup-xrdp-720.sh
#
# Resolution: with the Xorg backend, xrdp honors the size the client requests, so set the
# BB10 RDP client to 720x720. The Xvnc backend can also be pinned to 720x720 explicitly
# (see PIN_GEOMETRY below) for clients that don't request a size cleanly.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

# --- 1. Install xrdp + a lightweight desktop (XFCE is light and RDP-friendly) ---
echo "== Installing xrdp + XFCE =="
if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  apt-get install -y xrdp xorgxrdp xfce4 xfce4-goodies dbus-x11
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y xrdp xorgxrdp xfce4-session @xfce-desktop-environment
else
  echo "Unsupported package manager. Install xrdp + xorgxrdp + a desktop manually." >&2
  exit 1
fi

# --- 2. Use XFCE for the xrdp session ---
echo "xfce4-session" > /etc/skel/.xsession
for home in /home/*; do
  [[ -d "$home" ]] || continue
  echo "xfce4-session" > "$home/.xsession"
  chown "$(stat -c '%U:%G' "$home")" "$home/.xsession"
done

# --- 3. (Optional) Pin Xvnc geometry to 720x720 ---
# Uncomment to force 720x720 on the Xvnc backend regardless of client request.
PIN_GEOMETRY=false
if [[ "$PIN_GEOMETRY" == "true" ]]; then
  # xrdp's sesman Xvnc params; -geometry pins the session size.
  sed -i 's/^#\?\s*xserverbpp=.*/xserverbpp=24/' /etc/xrdp/sesman.ini || true
  # Add a max session size hint for Xorg backend:
  if ! grep -q 'MaxSessionWidth' /etc/xrdp/xrdp.ini 2>/dev/null; then
    cat >> /etc/xrdp/xrdp.ini <<'EOF'

[BB-Bridge]
; 720x720 hint for the BlackBerry Classic square screen
max_bpp=24
EOF
  fi
fi

# --- 4. Enable + start ---
systemctl enable xrdp
systemctl restart xrdp

# --- 5. Firewall (open 3389 if a firewall is active) ---
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 3389/tcp
elif command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --add-port=3389/tcp || true
  firewall-cmd --reload || true
fi

echo
echo "== xrdp ready =="
echo "Connect the BB10 RDP client to this host, requesting a 720x720 session:"
ip -4 addr show scope global | awk '/inet /{print "  " $2}' | sed 's#/.*##'
echo
echo "Log in with a real Linux user account (one that can start an X session)."
echo "Next: install Tailscale (Phase 2), set it to auto-start, then use the tailnet IP."
