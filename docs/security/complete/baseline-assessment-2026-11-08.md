# Security baseline: assessment + the decisions it produced (2026-11-08)

**Status:** assessment done, tasks opened. Nothing here is fixed yet except the
documentation it corrected.

## Task

Answer "how exposed is this homelab to an adversary?" from the live boxes rather
than from the docs, and turn the answer into work.

## What was found

Assessed by command on `ralph`, `tom`, Jason and the public edge. The posture
table lives in [`../README.md`](../README.md) — the headline:

- **Strong edge.** No WAN inbound at all: ufw denies by default, the only path in
  is one outbound Cloudflare tunnel on Ralph, and the tunnel's origin services all
  bind loopback. There is nothing to port-scan.
- **Soft interior.** The LAN (`192.168.1.0/24`) and the tailnet (`100.64.0.0/10`)
  are both trusted *whole* by ufw, and the tailnet has `ssh action: accept` with
  node key expiry disabled plus NOPASSWD sudo. Tom — the flakiest box — was a
  tailnet node with password SSH, VNC on `:5900`, no firewall and full sudo.

The compromise chain that follows: any LAN device → Tom → tailnet identity →
root on Ralph.

Two findings were not part of the original question and matter more than the
topology:

1. **`andrew-a-hale/homelab` is a public repo** and published the qBittorrent
   basic-auth password (plus the tailnet IPs and which host is the gateway). The
   credential is LAN/tailnet-scoped, so the impact is bounded, but it arrives with
   a map.
2. **Jellyfin is the only internet-facing authenticated app without a second
   factor**, and because cloudflared connects from `127.0.0.1` with `KnownProxies`
   unset, Jellyfin sees every internet request as local — IP-based protections and
   logs are blind.

## Decisions

- **No VLAN segmentation.** Rejected, not deferred. The D-Link DSL-X1852E's "VLAN"
  is WAN DSL tagging, not LAN separation; it offers a Guest Zone at best and that
  is wireless-only. Ralph and Tom are both on WiFi and that single link is already
  the bottleneck (0.74 MB/s measured). A VLAN router + managed switch would add a
  failure mode to the exact link everything depends on, for coverage that host
  hardening, per-service firewalls and tailnet ACLs already give. Revisit only with
  wired drops and a router that isn't the ISP's.
- **Proton Pass is the single store for human-held credentials** — one generated
  password per service, TOTP where offered, `pass-cli` for scripts. Cross-device
  coverage is why it wins over per-host plumbing.
- **Boot secrets do not go in Proton Pass.** `proton0`'s WireGuard config and
  `/etc/cloudflared/*` stay root-owned files on disk: a vault prompt at boot hangs
  an unattended reboot, which is the failure `RUNBOOK.md` exists to prevent.
  Machine tokens stay in the existing GPG `pass` store.
- **Tom is not a tailnet node.** The only thing it serves is tmpfs for Ralph, on the
  same /24. The subnet router for remote LAN access moves to Ralph — the box that is
  always on — and the never-expiring node key on the flakiest host goes with it.
  Fewer tailnet identities is the point, because the tailnet is trusted whole on the
  gateway.
- **Detection before more prevention.** fail2ban + Access alerts + a failed-auth
  count in the daily health log, because seven SSH password failures on Tom went
  unnoticed for a month.

## Corrections made while assessing

- Tom is **not** a web server. It runs the camera pipeline plus
  `python3 -m http.server` on the tailnet for Ralph. Several docs implied
  otherwise; `../README.md` and the lan-trust brief now say it explicitly.
- `AGENTS.md` calls qBittorrent's access control a "strict whitelist". It is a
  loopback bind plus nginx basic auth, with no IP whitelist. Corrected in the
  credentials brief.
- The `vpn` and `vpn-soak` symlinks in `~/.local/bin` on Jason pointed at the
  pre-rename `~/projects/tom/…` path and were broken; re-pointed at
  `~/projects/homelab/scripts/…` during this pass.

## Open work

`../README.md` → *Open work* (three briefs: lan-trust, credentials,
public-ingress).
