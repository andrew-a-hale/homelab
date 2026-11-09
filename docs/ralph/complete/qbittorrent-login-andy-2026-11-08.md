# qBittorrent login is andy; Tom's copy is gone (2026-11-08, creds updated 2026-11-09)

**The password in this file is stale.** `/etc/nginx/htpasswd` still has the
single `andy` entry, but the value was rotated after this was written
(`andy:pancake` now returns 401). Read it from
`pass show homelab/qbittorrent` — never paste it back into the repo, which is
how it rotted in the first place. One credential covers `/bt/` and `/nzb/`.

The `/bt/` basic-auth user on Ralph was `tom`/`pancake` — a leftover from the
Pi era. Tom stopped running qBittorrent when the stack moved to Ralph
(`qbittorrent-vpn-2026-11-07.md`), so the `tom` user meant nothing.

## What changed

- `/etc/nginx/htpasswd` on Ralph rewritten with a single entry: `andy`
  (`openssl passwd -apr1`, `htpasswd` is not installed on Arch). `tom` removed.
  `nginx -t` + reload; verified `andy` → 200, anonymous → 401, `tom` → 401.
  The password at the time was `pancake`; it has since been rotated and lives
  in `pass show homelab/qbittorrent` (verified 2026-11-09 against `/nzb/` → 200,
  which uses the same file).
- Docs corrected everywhere they still pointed at `http://tom/bt`, `tom/pancake`
  or `andy`/`homelab`: `RUNBOOK.md`, `TODO.md`, `docs/media/README.md`,
  `docs/server/README.md`, `docs/ralph/README.md`,
  `docs/ralph/complete/{qbittorrent-vpn,simplify}-2026-11-07.md`,
  `docs/ralph/complete/migration-2026-11-07.md`.

## Verified on Tom

`qbittorrent-nox@tom` → `inactive`, unit `not-found`, no `qbittorrent-nox`
binary, nginx inactive, no `/etc/nginx/htpasswd`. Nothing left to retire.

## Why andy, and why the password moved

One identity for the house's own services. `pancake` was already the shared
media password at the time; the previous `andy`/`homelab` in the media README had
drifted from reality, which is exactly how a doc rots. The password then rotted
the same way — recorded here as plaintext, rotated later without an update — so
as of 2026-11-09 the rule is: **the secret lives in `pass`, the doc says where,
nothing restates it.**

## Notes

- qBit's own WebUI stays `127.0.0.1:8081` on Ralph with auth off — the only
  door is nginx `/bt/`, LAN only, never through the Cloudflare tunnel.

  > **Correction 2026-11-08:** "never through the tunnel" was **false**. The
  > `/bt/` block lives on the `default_server`, which the tunnel routes to for
  > `andrewahale.com`, `www` and `placetime`, so `https://andrewahale.com/bt/`
  > answered 401 (basic auth only) on the public internet — 2667 logged `/bt/`
  > hits in nginx's logs. Now guarded: `if ($http_cf_ray) { return 404; }` in the
  > `/bt/` location (cloudflared always sets that header; `:80` is firewalled off
  > the WAN so nothing else can). Public 404, LAN/tailnet still 401.
- Rebuild path: `htpasswd`'s absence is now in `RUNBOOK.md`.
