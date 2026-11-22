# Google TV Streamer on the LAN (2026-11-22)

**Task:** the Streamer from `TODO.md` → Purchases has arrived and is powered on;
find it, make it play Jellyfin, and record it.

**Result:** found at `192.168.1.11`. Getting the app to connect took one firewall
fix and one URL gotcha (below). Jellyfin is reachable from it at
`http://192.168.1.26:8096/jf`.

## "Unable to connect" — what it actually was

Jellyfin's log had **zero** requests from `192.168.1.11`, so the app never
reached Ralph: it was the address it was given, not the server.

1. **`BaseUrl=/jf` is load-bearing.** The app pings `<url>/System/Info/Public`;
   at the root that is a `302` to `/jf/web/`, not JSON, so the check fails and
   the app says "unable to connect". The URL must carry the base path:
   `http://192.168.1.26:8096/jf`, or `https://jellyfin.andrewahale.com/jf`.
2. **`ralph` does not resolve on the TV.** That name only exists on Jason via
   tailnet MagicDNS and in Ralph's tunnel config; the D-Link has no record for
   it, so `http://ralph/jf` cannot work from the TV. Use the IP.
3. **`7359/udp` was blocked by ufw**, so auto-discovery silently did nothing
   (`ufw` only had `8096/tcp` for the LAN). Opened 2026-11-22:
   `sudo ufw allow from 192.168.1.0/24 to any port 7359 proto udp`. The server
   now answers the broadcast with `http://192.168.1.26:8096/jf` (it advertises
   the base path itself, so a discovered server connects).
4. The Streamer blocks ICMP — `ping 192.168.1.11` fails while the box is fine.
   Use `nmap -Pn` or mDNS to check it is alive.

## What it is

| | |
|---|---|
| Model | Google TV Streamer (`md=Google TV Streamer`, `fn=GoogleTV7641`) |
| IPv4 | `192.168.1.11` (DHCP lease on the D-Link) |
| mDNS name | `Android_fabca472a1424a20a0f052bb90051397.local` (`id=0d0ada90-…)` |
| Hardware MAC | `FA:8F:CA:ED:5B:B8` (the CAST/Google Home address; the wifi MAC differs) |
| Open ports | `6466` `_androidtvremote2._tcp` (remote app), `8009` `_googlecast._tcp` (Cast) |
| ICMP | blocked — the box is up, `ping` says unreachable. Use `nmap -Pn` / mDNS, not ping |
| Firewall | `8096/tcp` + `7359/udp` open from `192.168.1.0/24` (the UDP discovery rule added 2026-11-22) |

Discovery used, no router login needed:

```bash
avahi-browse -rt _androidtvremote2._tcp | grep address     # -> 192.168.1.11
avahi-browse -rt _googlecast._tcp | head -8                # model + fn + MAC
nmap -Pn -p 6466,8009 192.168.1.11                         # up, both open
```

## Why it matters

This retires the laptop-+-HDMI workaround and the whole VIDAA/DLNA dead end
(`dlna-rejected-2026-11-08.md`): the Streamer runs the official Jellyfin app, so
it direct-plays from Ralph's library instead of negotiating DLNA profiles with
the TV.

## What is left by hand (on the TV, not remotely fixable)

1. Play Store → **Jellyfin** → install. Nothing is installed yet: Jellyfin's log
   has no request from `192.168.1.11`.
2. Open it; it lists the server found over UDP `7359` and falls back to typing a
   URL — type it **with** the base path: `http://192.168.1.26:8096/jf` (a bare
   host:port gets "unable to connect").
3. Sign in as the guest user `callumbrowne`, or as `jellyfin` for admin work.

## Ceilings

- **No DHCP reservation.** `.11` is whichever lease the D-Link handed out. It
  does not matter for playback — the app finds the server by broadcast and the
  server address is on Ralph, not the TV — but if the address starts wandering,
  reserve it by MAC on the router (`pass 192.168.1.1-admin`).
- **No adb.** `adb install` / pairing over the network would need developer mode
  enabled on the device first, so installs stay manual.
- **Still on the main SSID.** The TV belongs on the guest zone with the bulb, but
  that task is blocked on the router UI (`../security/todo/lan-trust-2026-11-08.md` §6).
