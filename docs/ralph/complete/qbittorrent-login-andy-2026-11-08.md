# qBittorrent login is andy/pancake; Tom's copy is gone (2026-11-08)

The `/bt/` basic-auth user on Ralph was `tom`/`pancake` — a leftover from the
Pi era. Tom stopped running qBittorrent when the stack moved to Ralph
(`qbittorrent-vpn-2026-11-07.md`), so the `tom` user meant nothing.

## What changed

- `/etc/nginx/htpasswd` on Ralph rewritten with a single entry:
  `andy`/`pancake` (`openssl passwd -apr1`, `htpasswd` is not installed on
  Arch). `tom` removed. `nginx -t` + reload; verified `andy:pancake` → 200,
  anonymous → 401, `tom:pancake` → 401.
- Docs corrected everywhere they still pointed at `http://tom/bt`, `tom/pancake`
  or `andy`/`homelab`: `RUNBOOK.md`, `TODO.md`, `docs/media/README.md`,
  `docs/server/README.md`, `docs/ralph/README.md`,
  `docs/ralph/complete/{qbittorrent-vpn,simplify}-2026-11-07.md`,
  `docs/ralph/todo/migration-2026-11-07.md`.

## Verified on Tom

`qbittorrent-nox@tom` → `inactive`, unit `not-found`, no `qbittorrent-nox`
binary, nginx inactive, no `/etc/nginx/htpasswd`. Nothing left to retire.

## Why andy/pancake

One identity for the house's own services. `pancake` was already the shared
media password; the previous `andy`/`homelab` in the media README had drifted
from reality, which is exactly how a doc rots.

## Notes

- qBit's own WebUI stays `127.0.0.1:8081` on Ralph with auth off — the only
  door is nginx `/bt/`, LAN only, never through the Cloudflare tunnel.
- Rebuild path: `htpasswd`'s absence is now in `RUNBOOK.md`.
