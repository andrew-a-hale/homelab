# Security

How the homelab stands up to an adversary. Assessed **2026-11-08** from the live
boxes (`ralph`, `tom`) and the public edge — every claim below was verified by
command, not copied from a design.

## Verdict

**Strong edge, hardening interior.**

- The internet can only reach four hostnames, all through one outbound
  Cloudflare tunnel. ufw on Ralph is `default deny incoming` with **no WAN rule
  at all** — there is no port to scan.
- Both hosts now open ports per service rather than per subnet, Tom has no
  password SSH / no VNC / no rpcbind / a firewall, root on Tom needs a password,
  and three fail2ban jails watch the ways in (`complete/host-hardening-and-detection-2026-11-08.md`).
- What is left is identity-based: the tailnet still trusts any node that can
  authenticate, and Tom is still a node. That is the open work below.

## Verified posture

| Thing | State | Command that proves it |
|---|---|---|
| Inbound from WAN | none — tunnel dials out | `sudo ufw status verbose` on ralph |
| Public hostnames | `andrewahale.com`, `www`, `placetime` (public), `jellyfin` (own login), `petcam` (Cloudflare Access) | `curl -I https://<host>/` |
| Petcam | 302 → `cloudflareaccess.com`, one email, 24 h OTP session | `curl -sI https://petcam.andrewahale.com/` |
| Ralph listeners | `80`, `22`, `8096` (0.0.0.0); `8080/8081/8082` loopback only | `ss -tlnp` |
| Ralph sshd | `PasswordAuthentication no`, `PermitRootLogin no`, `AllowUsers andy` | `sudo sshd -T` |
| Ralph disk | LUKS2 + TPM2 PCR 7 auto-unlock, Secure Boot off (deliberate) | `docs/ralph/README.md` |
| Tom | sshd `PasswordAuthentication no`, `PermitRootLogin no`, `AllowUsers tom`; ufw active (tailnet + `22` from LAN); no VNC, no rpcbind; root needs a password. Still a tailnet node (never-expiring key, advertises `192.168.1.0/24`), and tailnet SSH bypasses sshd — Tailscale SSH answers as `using "none"` | `sshd -T`, `ufw status`, `sudo -l`, `ss -tlnp` on tom |
| Ralph ufw | per service: `22`/`80`/`8096` on `tailscale0`, `80`/`8096` from `192.168.1.0/24`, `41641/udp`. No blanket subnet rules | `sudo ufw status verbose` |
| Jellyfin proxy | `KnownProxies 127.0.0.1, ::1` — the real client IP reaches Jellyfin, so its logs and IP rules work | `X-Forwarded-For` probe in `complete/host-hardening-and-detection-2026-11-08.md` |
| Detection | fail2ban active, 3 jails (`sshd`, `nginx-http-auth`, `jellyfin`), loopback never banned; daily health log carries `auth/24h`, `bt-401`, `fail2ban`. **Bans only act on clients that reach Ralph directly** — tunnelled internet traffic arrives from `127.0.0.1`, so for Jellyfin it is detection, not prevention (no edge rule by decision) | `fail2ban-client status`, `scripts/homelab-health.sh` |
| Tailnet | `RunSSH: false` on both hosts — tailnet SSH is sshd + keys (`publickey`), not identity. No `ssh` block exists at all, so identity can never bypass sshd; rules are ralph `22,80,8096`, tom `22,8081`, `192.168.1.0/24`. Node key expiry disabled on ralph/tom (headless, verified `KeyExpiry: None`), left on for devices with browsers | `tailscale debug prefs`, `ssh -vv tom`, `docs/vpn/tailnet-acl.hujson` |

## The one chain that matters

```
any LAN device → tom → tailnet identity → root on ralph        ← DEAD 2026-11-08
```

The chain is broken at both interior hops, and by mechanism rather than by
documentation:

- **LAN → Tom**: key-only sshd, no VNC, no rpcbind, ufw, and root needs a
  password. A LAN device cannot reach Ralph's sshd at all (LAN `:22` firewalled).
- **Tom → identity**: Tailscale SSH is **off** on both hosts (`RunSSH: false`),
  so `ssh tom` now authenticates as `publickey` against sshd and
  `PubkeyAuthentication=no` is refused — verified. The sshd hardening therefore
  applies to the tailnet path too, which is exactly what it did not do before.
- The ACL still contains an `ssh` rule, but with no node running Tailscale SSH it
  has nothing to intercept; the replacement policy drops the block entirely
  (`../vpn/tailnet-acl.hujson`).

What is left is ordinary: a device that already holds a private key, or the
Jellyfin password. See the open briefs.

## Decisions

Assessment notes, decisions and the corrections they forced:
[`complete/baseline-assessment-2026-11-08.md`](complete/baseline-assessment-2026-11-08.md)
— no VLAN segmentation, Proton Pass as the one human-credential store, boot
secrets stay on disk, Tom leaves the tailnet, detection before more prevention.

## Open work

Nothing open in this project. The guest SSID (the only remaining item) is tracked
in `TODO.md` because it is a router click, not a homelab decision.

Deliberately declined, with the reasoning recorded: Cloudflare Access and an edge
rate-limit rule on Jellyfin (`complete/public-ingress-2026-11-08.md`), VLAN
segmentation and node tags (`complete/baseline-assessment-2026-11-08.md`,
`complete/tailnet-key-only-and-narrow-policy-2026-11-08.md`).

Done today: `complete/host-hardening-and-detection-2026-11-08.md`,
`complete/tailnet-key-only-and-narrow-policy-2026-11-08.md`,
`complete/qbittorrent-credential-rotation-2026-11-08.md`,
`complete/baseline-assessment-2026-11-08.md`.
