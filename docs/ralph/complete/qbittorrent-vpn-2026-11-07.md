# qBittorrent + Proton VPN on Ralph (done 2026-11-07)

**Decision:** Proton WireGuard, **inverted routing** — the VPN serves one app
(qBittorrent) and nothing else on the box knows it exists. qBit runs on Ralph,
bound fail-closed to `proton0`.

## The design (and why it changed mid-flight)

First attempt was Tom's shape: full tunnel (`wg-quick` default `Table=auto`),
then carve exceptions — a uid-range bypass for cloudflared, tailnet tolerance,
etc. That failed in a new way every hour:

- wg-quick inserts its policy rules **without explicit prefs** (98/99), landing
  above the cloudflared uid bypass at 100 → cloudflared egressed via VPN.
- The same rules swallowed ralph's replies to tailnet 100.x addresses →
  tailnet SSH broke the moment the tunnel came up.
- Every fix was another rule with another magic priority. That's the
  complexity the redesign was called for.

**Inverted:** `Table = off` in the wg config — wg-quick adds zero routes and
zero policy rules. One rule, added by PostUp:

```
ip rule add uidrange <qbittorrent-uid> lookup 51820 priority 100
ip route replace default dev proton0 table 51820
```

Only qBittorrent's uid can find the tunnel. Everything else (tailnet, SSH,
nginx, cloudflared, Jellyfin) routes normally by construction — no bypass
rules to get wrong. `cloudflared-bypass.service` and its script are **deleted**;
nothing to bypass.

Leak protection is unchanged and routing-independent: qBit's
`Session\Interface=proton0` binds every socket to the tunnel. Tunnel down →
traffic fails. Fail-closed.

## What was set up

- Proton dashboard → WireGuard → Linux → **Switzerland P2P (CH#403)** →
  `/etc/wireguard/proton0.conf` (600). Name `proton0` matters: qBit's
  `Session\Interface`, the service drop-in and `proton-guard.sh` all key on it.
- `Table = off` + PostUp/PostDown rule lifecycle in the config itself.
- `DNS =` line dropped from the *global* config: system DNS stays on the LAN
  resolver — Proton's `10.2.0.1` is only reachable via the tunnel, and pushing
  it globally would break DNS for everything whenever the tunnel is down.
  qBit's *own* lookups (trackers, DHT bootstrap) get a private DNS instead:
  systemd `BindPaths=` mounts `/etc/qbittorrent/{nsswitch.conf,resolv.conf}`
  into the service namespace — `hosts: files dns` (bypasses systemd-resolved)
  + `nameserver 10.2.0.1`. So tracker lookups go through the tunnel to Proton's
  resolver and never touch the ISP's DNS. Fail-closed like the rest: tunnel
  down → lookups fail → torrents stall instead of leaking.
- `qbittorrent-nox@qbittorrent` enabled; drop-in waits for `proton0` before
  start. WebUI on `127.0.0.1:8081`, nginx `/bt/` with basic auth
  `andy`/`pancake` (`/etc/nginx/htpasswd`; changed 2026-11-08, was `tom`).
- `/srv/media/{movies,.incoming}` owned `qbittorrent:jellyfin`, `g+rwX`, default
  ACL — Jellyfin reads new downloads without a chown.
- `proton-guard.sh` + `proton-guard.timer` (5 min) keep the tunnel up.
- Two fixes found at first start:
  - qBit's home was owned by the package's `qbt` user (965) while the service
    runs as `qbittorrent` (960), `.config` was root-owned and `.cache` missing
    → Qt fatal on startup (core dump). One `chown -R` + `install -d` fixed it.
  - Arch ships no `resolvconf`; `wg-quick` wants one *only when the config has
    a `DNS =` line*. Shim installed anyway —
    `/usr/local/bin/resolvconf → /usr/bin/resolvectl` (systemd-resolved
    implements the resolvconf interface) — so a future `DNS =` edit can't fail
    the whole tunnel bring-up.

## Why not the Proton CLI

`proton-vpn-cli` SSO needs a Secret Service keyring; headless Ralph has none,
five `signin` attempts, zero persisted sessions (see the pre-move notes in git
history). WireGuard config: same protection, no daemon, no D-Bus.

## Verified (2026-11-07)

```
qbit uid egress:     146.70.226.228   (Swiss, via proton0)
andy uid egress:     220.244.74.53    (bare AU ISP)
cloudflared egress:  220.244.74.53    (bare AU ISP)
ip rule show:        exactly 1 uid rule (960 → 51820), nothing at 98/99
qbit listen sockets: bound to 10.2.0.2%proton0 / [2a07:…]%proton0 only
qbit DNS:            resolves trackers only via Proton's 10.2.0.1 (positive
                     test: bttracker.debian.org resolves as uid 960; negative
                     test: same lookup as uid 1000 fails — no fallback to LAN)
tailnet SSH to ralph: ok
https://andrewahale.com/: 200
```

## Rollback

`systemctl stop qbittorrent-nox@qbittorrent; wg-quick down proton0; rm
/etc/wireguard/proton0.conf`. Torrents stop dead by design (interface binding).

## What the ISP can see / not see

- **Not:** torrent bytes, tracker HTTP, peer connections, tracker/DHT DNS
  lookups — all inside WireGuard to Proton.
- **Not:** inbound peers — qBit's listen sockets bind to `%proton0`, packets on
  other interfaces can't reach them.
- **Yes:** that you run a VPN (encrypted WireGuard UDP to a known Proton IP),
  and traffic volume/timing patterns. Unavoidable with any VPN.

## Left open

- qBit on Tom is still running; Tom's own Proton/qBit stack retires per
  `migration-2026-11-07.md` (done 2026-11-08).
- IPv6 egress via proton0 exists (address assigned) but was not exercised;
  qBit binding covers it either way.
