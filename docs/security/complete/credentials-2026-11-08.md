# Credentials: rotated out of the public repo, Proton Pass adopted (2026-11-08)

**Status:** done 2026-11-08. §1 was executed and verified; §2 landed the same day
— the owner copied the secret into Proton Pass and the interim `pass` entry was
removed, so there is one store. Source: `docs/security/README.md`.

## Why

`andrew-a-hale/homelab` is a **public** repo (verified:
`api.github.com/repos/andrew-a-hale/homelab` → `"private": false`) and it
publishes the qBittorrent basic-auth password in plaintext:

- `docs/media/README.md:12`
- `docs/ralph/README.md:80`

The same password is the `apr1` hash in `/etc/nginx/htpasswd` on Ralph. It is
not internet-reachable (ufw blocks WAN, the tunnel does not route `/bt/`), so
this is a LAN/tailnet credential — but the repo also hands over the topology,
tailnet IPs and which box is the gateway, so the credential arrives with the
map. Rotate it regardless of what else happens.

## 1. Rotate — **DONE 2026-11-08**

What was run, and what to repeat next time:

```bash
PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
HASH=$(printf '%s\n' "$PW" | openssl passwd -apr1 -stdin)   # htpasswd is NOT on ralph
printf 'andy:%s\n' "$HASH" | ssh ralph 'sudo tee /etc/nginx/htpasswd >/dev/null && sudo systemctl reload nginx'
printf '%s\n' "$PW" | pass insert -m -f homelab/qbittorrent
```

Verified: no credentials → 401, old password → 401, stored password → 200. The
value is gone from both READMEs and from `RUNBOOK.md`.

While in there: `qBittorrent.conf` has `WebUI\LocalHostAuth=false`, i.e. the
WebUI demands auth from localhost too, which is why nginx's basic auth is the
only door. Fine — but note `AGENTS.md` calls this a "strict whitelist", which
it is not. Fix the doc line.

## 2. Proton Pass as the single human-credential store — **DONE**

Coverage across devices is the whole reason: phone, laptop, both servers, no
per-device plumbing. One vault for the homelab, one random password per
service.

| Credential | Today | After |
|---|---|---|
| ralph `/bt/` basic auth | `pancake`, published | generated, in Pass |
| Jellyfin admin | "a secure password" (undocumented) | generated, in Pass, TOTP if the login supports it |
| Router (D-Link DSL-X1852E) | sticker | in Pass |
| Cloudflare dashboard | browser session | in Pass, TOTP already on the account |
| GitHub | account password | in Pass, TOTP |
| Proton account | — | in Pass (or the account vault) |

- `pass-cli` (official, `protonpass/pass-cli`) for the scripts that need a
  value at runtime. Do **not** wire it into unit files that start at boot.
- **Boot-critical secrets stay on disk, root-owned:** `/etc/wireguard/proton0.conf`,
  `/etc/cloudflared/{config.yaml,cert.pem,<tunnel-id>.json}`. A vault prompt at
  boot hangs an unattended reboot — the exact failure `RUNBOOK.md` prevents.
- **Two stores is the real risk.** `pass` (GPG) already holds
  `dev/openrouter` and the Proton Drive token (`docs/backups/README.md`).
  Rule: machine tokens stay in `pass`, anything a human types goes in Proton
  Pass. Write that rule into `RUNBOOK.md`'s secrets table so the next cold
  rebuild isn't guessing.

## Done when

- `/bt/` works with a password that appears nowhere in the repo or in shell
  history.
- `grep -rn "pancake" docs RUNBOOK.md AGENTS.md` returns only the cat names.
- `RUNBOOK.md`'s secrets table says which store each secret lives in.
- Proton Pass has every human-typed credential in the table above.
