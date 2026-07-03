# Use the BlackBerry from ANYWHERE (not just home Wi-Fi)

Goal: the home laptop stays on running the mirror; the BlackBerry, on mobile data or any
other Wi-Fi, opens one web address and controls it.

Because a BB10 phone can't install a VPN app, the laptop has to **publish** the mirror at a
stable public address. We use **Tailscale Funnel** — free, encrypted (HTTPS), a fixed URL
per machine, no router configuration, survives reboots.

```
  BlackBerry (anywhere)  --HTTPS-->  <machine>.<tailnet>.ts.net  --Funnel-->  laptop:8080
```

## Setup (once, on the HOME laptop)

1. Make sure the normal bridge already works on Wi-Fi (START BRIDGE, phone connects on the
   local address). Remote is a layer on top of that.
2. Double-click **`ENABLE-REMOTE.cmd`**.
   - It installs Tailscale and opens a browser to **sign in** (make a free account).
   - It turns on Funnel for port 8080 and keeps the laptop from sleeping.
3. **One-time Tailscale toggle:** the very first time, Tailscale may print a link saying
   *"Funnel is not enabled for your tailnet."* Open that link, flip the **Funnel** switch on
   in the Tailscale admin console, then run `ENABLE-REMOTE.cmd` again. (Tailscale requires
   this manual opt-in once, per account — there's no way around it, but it takes 10 seconds.)
4. It prints the public address, like:
   `https://cousins-laptop.tailXXXX.ts.net/?k=483920`

## Daily use

- Home laptop: **START BRIDGE** must be running (it serves the mirror; Funnel only
  publishes it). START BRIDGE now prints **both** addresses — the local one and the
  "Anywhere" one.
- BlackBerry, anywhere with internet: open the **Anywhere** address (code included).

Leave the laptop **on** and connected to the internet. Closing the lid can sleep it — set
"when I close the lid: do nothing" in Windows power settings, or just leave it open.

## The ONE thing to test on the actual phone

A BlackBerry Classic is a 2014-2016 device. Modern HTTPS uses a certificate (Let's Encrypt
/ ISRG Root X1) that *most* BB10 devices trust, but a phone that never got its later
software updates might show a **certificate warning** on the `.ts.net` page.

- **If the page loads normally** → you're done, it works anywhere.
- **If it shows a certificate/security error** → the old phone doesn't trust the modern
  cert. Use the plain-HTTP fallback below (no certificate involved, works on any browser).

This is the single thing that can't be confirmed without the physical phone in hand, so
test it once at home before relying on it out in the world.

## Fallback if the phone rejects the HTTPS certificate: plain HTTP (one double-click)

This serves the SAME mirror over plain `http://` (no certificate at all), so even the oldest
browser renders it. It's now automated — double-click **`ENABLE-FAILSAFE.cmd`** and it:

- confirms the mirror is up on 8080 and that the firewall allows it,
- detects your home public IP,
- **tries to open the router port automatically (UPnP)** — if the router allows it, there's
  no manual router step at all,
- optionally updates a free **DuckDNS** name so the address is stable (see below),
- prints the exact URL, e.g. `http://<your-home-ip>:8080/?k=<your-code>`, and saves it.

If the router doesn't support UPnP, the script prints the exact one-time port-forward to do
in the router admin page (`http://192.168.1.1`): forward external TCP **8080** → this
laptop's LAN IP port **8080**. That's the only manual step, and it sticks.

**Optional stable name (DuckDNS):** so the address survives a home-IP change, create a free
name at <https://www.duckdns.org> (sign in with Google/GitHub, ~30 sec), then either let
`ENABLE-FAILSAFE.cmd` prompt you for the name + token, or drop a file
`host-setup\duckdns.txt` containing one line: `yourname  your-token`. The URL then becomes
`http://yourname.duckdns.org:8080/?k=<code>`. (The token is a secret — it's gitignored.)

The access code + the built-in brute-force lockout (8 wrong codes = 15-minute ban per
source) are what protect this exposed port. Keep the code secret; that's the lock.

## Security notes

- Every request needs the `?k=` code; without it the server returns a 403 page and serves
  nothing. Wrong codes are rate-limited and then temporarily banned per source IP.
- This is demo/personal-grade protection, appropriate for one person's phone reaching one
  home laptop. Don't post the address publicly.
- To rotate the code: delete `host-setup\bridge_access_key.txt` and run START BRIDGE again.
- To turn remote OFF entirely: `tailscale funnel reset` (or just quit Tailscale). The local
  Wi-Fi mirror keeps working regardless.
