# Host hardening, per-service firewalls and detection (2026-11-08)

**Status:** done on Tom and Ralph. Internet-side Access/WAF still blocked on a
human (see the open briefs). Source: `../todo/lan-trust-2026-11-08.md` §1–2 and
`../complete/public-ingress-2026-11-08.md` §2–4.

## Task

Stop trusting zones by address, close Tom's soft path to root, and make the
"someone tried" question answerable. Nothing here changes what the homelab does.

## Tom (`docs/server/README.md`)

| # | Change | Verified by |
|---|---|---|
| 1 | sshd: `PasswordAuthentication no`, `PermitRootLogin no`, `KbdInteractiveAuthentication no`, `AllowUsers tom` in `/etc/ssh/sshd_config.d/99-hardening.conf` | `sshd -T`; LAN key login works, LAN password login → `Permission denied (publickey)` |
| 2 | Deleted `/etc/ssh/sshd_config.d/50-cloud-init.conf` (it said `PasswordAuthentication yes` and, being first in glob order, **won** over any later drop-in). Backup: `/root/50-cloud-init.conf.bak-20261108` | `sshd -T` |
| 3 | `wayvnc.service` + `wayvnc-control.service` disabled — `:5900` is gone. Nothing in the petcam path used it | `ss -tlnp`, LAN connect refused |
| 4 | `rpcbind.service` + `rpcbind.socket` disabled — `:111` gone | `ss -tlnp` |
| 5 | ufw installed: default deny incoming, `allow in on tailscale0`, `41641/udp`, `22/tcp` from `192.168.1.0/24` | `ufw status verbose`; petcam still `200` from Ralph |
| 6 | sudo: `/etc/sudoers` had a bare `tom ALL=(ALL) NOPASSWD: ALL`. Replaced with `tom ALL=(root) NOPASSWD: /usr/local/bin/wifi-guard.sh` — the only passwordless caller (cron). Group `sudo` still gives passworded admin. Backup `/root/sudoers.bak-20261108` | `sudo -n -l`; wifi-guard runs; an arbitrary root command demands a password |

**Consequence worth knowing:** root on Tom now needs Tom's account password. That
password exists (set 2026-04-13) and is the owner's; if it is ever lost, Tom needs
a console.

### The finding that changes the plan

Tailnet SSH to Tom does **not** go through sshd. Connecting to
`tom.tailad1015.ts.net:22` is handled by **Tailscale SSH** and completes as
`Authenticated to … using "none"` — tailnet identity, no key, no password. So the
sshd hardening above protects the LAN path only; the tailnet path is governed by
the ACL (`action: "accept"`, node key never expires). That is exactly why
`../todo/lan-trust-2026-11-08.md` §3 (tagged, `check` mode) and §5 (Tom off the
tailnet) are the remaining high-value items, and why they can only be done in the
admin console.

## Ralph

| # | Change | Verified by |
|---|---|---|
| 1 | ufw narrowed from zone-wide to per-service: `22`, `80`, `8096` on `tailscale0`; `80` and `8096` from `192.168.1.0/24`; `41641/udp` kept. The blanket `allow from 192.168.1.0/24` and `allow from 100.64.0.0/10` are deleted | LAN `:22` now times out; LAN `:80` → 200 and `:8096` → 302; tailnet ssh unaffected |
| 2 | Jellyfin told it is behind a proxy: `<KnownProxies>127.0.0.1, ::1</KnownProxies>` + `IsRemoteAccessAllowed` in `/etc/jellyfin/network.xml`. Backup `/root/network.xml.bak-20261108` | a request with `X-Forwarded-For: 198.51.100.7` is logged by Jellyfin with that IP (5/5 lines) |
| 3 | fail2ban 1.1.1 (pacman) with `/etc/fail2ban/jail.local`: `sshd` (systemd backend), `nginx-http-auth` (file backend), `jellyfin` (custom filter `filter.d/jellyfin.conf`) | `fail2ban-client status` shows 3 jails; a real ban appears in `nft list ruleset` |
| 4 | `ignoreip = 127.0.0.1/8 ::1` in `[DEFAULT]` — **cloudflared reaches every origin from loopback**, so a ban there would take the whole public site down | config |

Ban chain proven end-to-end, then cleaned up:

- 5 bad `/bt/` logins → `nginx-http-auth` banned `192.168.1.181` (Jason's LAN IP).
- 5 bad Jellyfin logins with a spoofed `X-Forwarded-For` → `jellyfin` jailed
  `198.51.100.7`, and `nft list ruleset` contained the address.
- Both unbanned afterwards.

The custom filter, because Jellyfin has no shipped one:

```
failregex = ^.*Authentication request for .* has been denied \(IP: <HOST>\)\.?$
```

## Ceiling: a ban at the origin does not travel through the tunnel

**Corrected 2026-11-08, same day.** The bans above work for clients that reach
Ralph directly — everything on the LAN (so `/bt/`, the site through `http://ralph/`,
and any LAN Jellyfin client). They do **not** stop an internet client: cloudflared
dials out and connects to each origin from `127.0.0.1`, so a ban on
`198.51.100.7` drops packets that will never arrive — the client's traffic still
enters through the tunnel and is proxied to the origin from loopback (which is
deliberately in `ignoreip`).

So for tunnelled traffic fail2ban is **detection, not prevention**: it tells you
someone is spraying (`auth/24h` in the daily log, and the notification ask in
`../complete/public-ingress-2026-11-08.md`), but the throttle has to sit at the edge —
a Cloudflare WAF rate-limiting rule on
`POST /jf/Users/AuthenticateByName`. Free plan includes 5 custom rules and **1**
rate-limiting rule, which is exactly enough for this.

Blocking tunnelled abuse from the origin would need the origin to see real
client IPs *and* act on them — i.e. nginx `deny` fed from Jellyfin's log, or
dropping the client at Cloudflare. Not worth building for one household; the edge
rule is the lazy correct answer.

## Health check (`scripts/homelab-health.sh`)

- New `AUTH_WARN_MAX=20` threshold and `auth_class()`, selftested.
- `auth/24h` on **both** hosts (Tom: `journalctl -u ssh`, Ralph: `-u sshd`).
- `bt-401` (nginx 401s on `/bt/`) and `fail2ban` (banned right now) on Ralph.
- First run with the new checks: `pass=22 warn=1 fail=0` — the single WARN is
  Tom's 4 boots/24h, i.e. the camera bug, not security.
- `skills/homelab-health/SKILL.md` table updated to match (and its petcam
  playbook corrected: the app is on Ralph at `:8082`, not Tom at `:8080`).

## Still open (blocked on a human/browser)

| Item | Why blocked |
|---|---|
| Tailnet ACL: tags, `check` mode, expiry back on for devices | needs `login.tailscale.com` or an API key with device+ACL scope; no key on any box |
| Tom off the tailnet (subnet router moves to Ralph) | the route has to be approved in the console first |
| Cloudflare Access in front of `jellyfin.andrewahale.com` | needs a write-scope Access token; the tunnel's `cert.pem` token is read-only |
| WAF rate limit on Jellyfin's login | dashboard rule |
| Guest SSID for IoT/TV/phones | router UI (`pass` has `192.168.1.1-admin`) |

## Revert

Each change has a `.bak-20261108` beside it (`/root` on Tom, `/root` on Ralph).
Tom: restore `50-cloud-init.conf`, re-enable `wayvnc`/`rpcbind`, `ufw disable`,
restore sudoers. Ralph: `ufw allow from 192.168.1.0/24`, restore `network.xml`,
`systemctl disable --now fail2ban`.
