# qBittorrent + Proton VPN on Ralph (2026-11-07)

**Status:** qBittorrent installed and configured, **not running** — waiting on a
VPN. Proton's CLI is a dead end on a headless box; switching to WireGuard.

## Done

- `extra/qbittorrent-nox`, config migrated verbatim from Tom
  (`/var/lib/qbittorrent/.config/qBittorrent/qBittorrent.conf`):
  - `Session\Interface=proton0` — the fail-closed bind: no VPN, no torrent traffic
  - `Session\InterfaceAddress` **removed** — Proton hands out a new `10.2.0.x` per
    session, so pinning it guarantees a break later
  - `DefaultSavePath=/srv/media/movies`, `TempPath=/srv/media/.incoming/`
  - `WebUI\Address=127.0.0.1`, `WebUI\Port=8081`, so the WebUI is never exposed
    directly — nginx `/bt/` puts basic auth in front, using **Tom's htpasswd**
    (`andy:$apr1$…`) so the login did not change
- `/srv/media/movies` and `.incoming` owned `qbittorrent:jellyfin`, `g+rwX`, with
  a default ACL so Jellyfin can read new downloads without a chown.
- `qbittorrent-nox@qbittorrent.service` + drop-in that **refuses to start until
  `proton0` exists** (60×2s wait, then fail). Enabled, not started.
- `cloudflared` moved off root to its own user (uid 966) *before* any VPN existed,
  plus `cloudflared-bypass.service` adding
  `ip rule add uidrange 966-966 lookup main priority 100` — Tom's trick, needed
  because Proton's policy routing swallows everything else.
- `scripts/proton-guard.sh` + `proton-guard.timer` (5 min) replace Tom's `*/5`
  cron: bring the VPN back if the interface disappears.

## Why the CLI can't be used here

`proton-vpn-cli 1.0.5` (same version as Tom's Debian package) fails twice over on
a headless server:

1. **`_vpn_gui_running()` uses the session D-Bus bus** before every command →
   `dbus_fast InvalidAddressError: DBUS_SESSION_BUS_ADDRESS not set`. Tom only
   survives this because cron exports `DBUS_SESSION_BUS_ADDRESS=…/bus`.
   Worked around with `/usr/local/bin/protonvpn`, a wrapper pointing it at the
   system bus (the "is a GUI running?" answer is correctly *no*).
2. **The SSO session needs a Secret Service keyring.** `proton/keyring_linux`
   ships only libsecret/SecretService backends — no file backend, no override that
   isn't a rebuilt Python package. `signin` therefore appears to succeed and the
   session is gone by the next command: `protonvpn status` → `Status: Disconnected`.

Five `signin` attempts in the shell history, zero persisted sessions. Bolting a
headless gnome-keyring on would work but means storing the unlock password on the
same disk as the keyring, i.e. no better than a plaintext wireguard key, with far
more moving parts.

## Next: WireGuard

Proton's WireGuard config gives the same protection with no daemon, no D-Bus and
no keyring:

1. Proton dashboard → Downloads → WireGuard configuration → Linux → a
   **Switzerland, P2P** server.
2. Save as `/etc/wireguard/proton0.conf` (mode 600). Naming it `proton0` matters:
   the interface keeps that name, so qBittorrent's `Session\Interface=proton0`,
   the systemd drop-in and `proton-guard.sh` all work unchanged.
3. `systemctl start proton-guard.service` (or `wg-quick up proton0`), then
   `systemctl start qbittorrent-nox@qbittorrent`.

Verify, in this order:

```bash
curl --interface proton0 -s ifconfig.me          # Swiss IP, not the AU ISP
sudo -u qbittorrent curl -s ifconfig.me          # qBit's uid egresses via VPN
sudo -u cloudflared curl -s ifconfig.me          # cloudflared still bare ISP
curl -s https://andrewahale.com/ -o /dev/null -w '%{http_code}\n'   # 200
```

WireGuard's default `Table=auto` gives a full tunnel with the usual
`suppress_prefixlength 0` rule, so LAN/SSH keeps working while internet traffic
goes through Switzerland — same shape as Tom's setup.

## Unrelated error found in the logs

`guix pull` still dies with `guix pull: error: Git error: SSL error: unknown
error` even with `SSL_CERT_FILE`/`GIT_SSL_CAINFO`/`SSL_CERT_DIR` pointed at both
Arch's bundle and Guix's own `nss-certs`. Guix's HTTPS path works fine
(`guix install nss-certs` succeeded), so it is libgit2 specifically, not the
network. Not blocking: the installed Guix 1.5.0 can install packages; only
`guix pull` (updating Guix itself) is unavailable.
