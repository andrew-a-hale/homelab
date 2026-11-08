# Tailnet: key-only SSH and a narrow policy (2026-11-08)

**Status:** done and enforced. Source: `../todo/lan-trust-2026-11-08.md` §3.

## Why this mattered

Tailnet SSH to Tom was **Tailscale SSH**, not sshd — `ssh -vv` reported
`Authenticated to … using "none"`, while the same box over the LAN demanded a key.
That made Tom's sshd hardening (done the same day,
`host-hardening-and-detection-2026-11-08.md`) decorative on the tailnet path:
anyone holding the tailnet identity got a shell, no key, no prompt. It also meant
the ACL, not sshd, was the whole security boundary for that box.

## What was done

**1. Turned Tailscale SSH off on both hosts** — no re-auth, nothing broke:

```bash
ssh ralph 'sudo tailscale set --ssh=false'
ssh tom   'sudo tailscale set --ssh=false'
```

The Tom command closed the session it was running in — that is the change taking
effect. Note `tailscale set`, not `tailscale up`: `up` can trigger a re-auth.

**2. Replaced the policy** (`../../vpn/tailnet-acl.hujson`): three rules, no `ssh`
block, no tags.

```
autogroup:member → 100.108.202.106:22,80,8096   # ralph: sshd, nginx, Jellyfin
autogroup:member → 100.77.132.110:22,8081       # tom: sshd, petcam file server
autogroup:member → 192.168.1.0/24:*             # remote LAN access (subnet router)
```

## Verified

| Check | Result |
|---|---|
| `ssh -vv tom` | `Authenticated … using "publickey"` |
| `ssh -o PubkeyAuthentication=no tom` | `Permission denied (publickey)` — identity auth gone |
| ralph → `tom:8081` still/images | `200` / `200` |
| jason → `ralph:8096` (Jellyfin) | `302` |
| jason → `tom:8081` | `200` |
| **negative:** ralph → jason`:22` (not in policy) | **blocked** |
| `scripts/homelab-health.sh` | `pass=22 warn=1 fail=0` (the WARN is Tom's reboot counter) |

## Decisions, including the ones that look like omissions

- **No `ssh` block at all.** Re-adding any rule here hands authentication back to
  the tailnet identity. Keys already exist (Jason → tom, ralph) and they survive
  a compromised tailnet account.
- **Not `action: "check"`.** It forces a browser re-auth every 12 hours, which
  would silently break the unattended 08:00 health check that ssh's both hosts.
  Tempting, wrong.
- **No tags yet.** Tagging a node forces a re-auth, and a re-authed node is
  unreachable until someone opens the login URL. Ralph is headless behind
  LUKS+TPM, so this waits for a pre-created auth key and a moment when nobody
  depends on remote access.
- **`dst` takes an address, not a machine name.** `"ralph:22"` is rejected as
  `invalid address`; the policy uses tailnet IPs, with the IP map in the file's
  comment. Re-adding a node gives it a new IP — update the file.
- **`src` cannot be a hostname** (only tags/groups/autogroups/users), hence
  `autogroup:member`.

## Consequence

`LAN → tom → tailnet identity → root on ralph` is dead: the middle hop needs a
private key now, and Tom's sshd hardening applies to every path. Per-node SSH into
anything except ralph and tom is denied by policy.

## Left open

Guest SSID (router UI), the optional Cloudflare rate-limit rule on Jellyfin's
login, and moving the rotated qBittorrent password from `pass` into Proton Pass.
Tags and the subnet-route move to Ralph are deliberate non-goals for now.
