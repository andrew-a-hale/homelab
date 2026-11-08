# qBittorrent credential rotated out of the public repo (2026-11-08)

**Status:** done, verified. Source: `../complete/credentials-2026-11-08.md` §1.

## The problem

`andrew-a-hale/homelab` is a **public** repo (`"private": false`) and it published
the `/bt/` basic-auth password in plaintext — `docs/media/README.md` and
`docs/ralph/README.md` — while the same value was the hash in
`/etc/nginx/htpasswd` on Ralph. Not internet-reachable (ufw has no WAN rule and
the tunnel does not route `/bt/`), but it is a working LAN/tailnet credential
published alongside the tailnet IPs and the name of the gateway.

## What was done

1. Generated a 24-character alphanumeric password (no shell metacharacters, so it
   survives `curl -u`, a browser, and a `htpasswd` line).
2. Hash: `openssl passwd -apr1 -stdin`. `htpasswd` is **not installed** on Ralph —
   use openssl.
3. Rewrote `/etc/nginx/htpasswd` (`andy:<hash>`) and `systemctl reload nginx`.
4. Stored the plaintext in the GPG `pass` store: `pass homelab/qbittorrent`
   (created on Jason).
5. Removed the value from both READMEs and from `RUNBOOK.md`, replacing it with a
   pointer to the store.

## Verified

| Request | Result |
|---|---|
| no credentials → `/bt/` | `401` |
| old password → `/bt/` | `401` (the published one no longer works) |
| `pass show homelab/qbittorrent` → `/bt/` | `200` |

## Decision: where the secret lives

The target state (`baseline-assessment-2026-11-08.md`) is **Proton Pass for
human-held credentials, `pass` for machine tokens**. Proton Pass has no scriptable
session here, so the rotation was staged in `pass homelab/qbittorrent` as an
interim; the owner then copied it into Proton Pass and the `pass` entry was
removed the same day. One store, as intended.

Boot-critical secrets stay where they are (root-owned files on Ralph):
`/etc/wireguard/proton0.conf`, `/etc/cloudflared/*`. A vault prompt at boot hangs
an unattended reboot.

## History files still contain the old value

`docs/ralph/complete/qbittorrent-login-andy-2026-11-08.md`,
`…/qbittorrent-vpn-2026-11-07.md`, `…/simplify-2026-11-07.md`. Left in place on
purpose: they are the record of what was done, and the value they name is now dead
everywhere. Rewriting git history for a revoked LAN credential buys nothing.

## Also corrected

`AGENTS.md` described qBittorrent as "network only, strict whitelist". It is a
loopback bind plus nginx basic auth with **no IP whitelist** — the firewall and
the tunnel's ingress do the scoping. Fixed there and in `docs/media/README.md`.
