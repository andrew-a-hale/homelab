# VPN

Three separate jobs, three tools — no shared switch. The homelab does not route
everything through a VPN; it uses each where it earns its place.

| Job | Tool | Where |
|---|---|---|
| Traffic privacy, opt-in per device | **Proton VPN CLI** (`protonvpn`) | Jason (desktop), by hand |
| Torrent safety | qBittorrent **interface-bound to `proton0`** | Ralph only |
| Remote access | **Tailscale** (LAN + SSH) and **Cloudflare tunnel** (public HTTP) | all hosts |

## Proton VPN

**Jason** — `vpn` is `scripts/vpn`, symlinked into `~/.local/bin`:

| Command | Does |
|---|---|
| `vpn off` | disconnect, bare ISP |
| `vpn any` | connect, fastest exit |
| `vpn safe` | connect `--country Switzerland --p2p` |
| `vpn status` | `protonvpn status` + public IP |

`vpn any` verifies end-to-end and exits non-zero with a fix hint (route checks can
pass while DNS/traffic is dead). `vpn-soak [minutes] [modes…]` cycles modes and
probes every 5 s, logging to `~/vpn-soak-<ts>.log`. Phones/tablets: the Proton
app is the whole story.

**Ralph** — `wg-quick@proton0` with `/etc/wireguard/proton0.conf` (secret, not in
this repo), plus `proton-guard.timer` every 5 min running `scripts/proton-guard.sh`
(installed at `/usr/local/bin/`), which re-raises the interface if it drops. The
guard, not the unit, is what keeps the tunnel up in practice.

The tunnel is **inverted routing**: `Table=off` plus one uid rule, so only
qBittorrent's uid uses it. Nothing else on Ralph knows the VPN exists.

**Kill switch stays off.** Its dummy interface is what broke DNS on Jason
(`complete/away-dns-blackhole-2026-10-22.md`), and interface binding already
covers the leak that matters: qBittorrent's sockets have nowhere to go when
`proton0` is down.

One-time sign-in per host: `protonvpn signin <user> --totp`. The session survives
reboots; you only re-auth after a Proton password change, keyring wipe or
Proton-side revocation — the symptom is `Authentication required` from
`vpn any`/`protonvpn connect`.

## Tailscale

- **No Tailscale SSH anywhere.** `RunSSH: false` on both hosts, so tailnet SSH is
  plain sshd with keys (`ssh -vv tom` → `using "publickey"`). This is deliberate:
  Tailscale SSH authenticates by tailnet identity and bypasses sshd entirely, so
  with it on, Tom's sshd hardening covered nothing on the tailnet path.
- **Policy** is `docs/vpn/tailnet-acl.hujson` — narrow by host and port
  (`ralph:22,80,8096`, `tom:22,8081`, the LAN route), no `ssh` block. Tags are
  deliberately absent: tagging forces a re-auth and the node is unreachable until
  someone opens the login URL. Do that later with a pre-created auth key, never
  with `action: "check"` (a 12-hourly re-auth breaks the 08:00 health check).
- **Node key expiry is disabled on the headless boxes only** (`ralph`, `tom`) —
  no console, no browser, so an expiring key would mean a dead gateway. Verified
  2026-11-08: `KeyExpiry: None` for both. `jason`, `rose` and `iphone-11` keep the
  default expiry (they have browsers).
- `tom` advertises `192.168.1.0/24` (approved in the admin console) so the phone
  can reach the LAN from anywhere. Moving the route to Ralph would need an
  approval click; leaving it on Tom is fine now that Tom is key-only.
- Clients: `iphone-11` (remote LAN access), `jason` and `rose` on the LAN. One
  toggle per device; NAT traversal, never port-forwarding.

## Public HTTP

One Cloudflare tunnel, on Ralph, outbound-only — no WAN inbound anywhere in the
house. Ingress shape: `../ralph/cloudflared-config.yaml`. Public hostnames and
their auth: `../website/README.md`.

## Verify

```bash
~/.local/bin/vpn status                       # jason: connected + exit IP
ssh ralph 'sudo wg show proton0 | head -4'    # handshake age
ssh ralph 'systemctl is-active wg-quick@proton0 proton-guard.timer'
tailscale status                              # peers, and who is expired
```

## Ceilings

- **No VPN on the public path.** The website, Jellyfin and the tunnel ride the
  bare ISP; the Cloudflare tunnel is outbound TLS and does not need a VPN.
- Ralph's Proton endpoint is a single AU peer; a Proton-side outage is a
  qBittorrent outage, not a Ralph outage (nothing else uses the interface).

History: `complete/` — the Proton CLI + Tailscale redesign (and everything it
deleted), Switzerland exit, the route approval, the kill-switch DNS blackhole, and
the headless key-expiry decision. Tom's Proton stack is gone with the migration
(`../ralph/complete/qbittorrent-vpn-2026-11-07.md`).
