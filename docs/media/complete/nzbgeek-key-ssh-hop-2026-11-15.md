# Decision: nzb-dl.sh reads the NZBGeek key from Ralph over SSH

Date: 2026-11-15

## What happened

Running `nzb-dl.sh` from Jason failed with "no NZBGeek key": `geek_key` only tried
a local `sudo -n systemd-creds decrypt` (no such cred on Jason) and then
`pass show homelab/nzbgeek/apikey` — but the `pass` store is locked because the
agent has no way to enter the GPG passphrase (`pinentry-tty`, no TTY from agent
tool calls; owner confirmed they cannot type it right now).

Ralph's credential decrypts fine over SSH (`ssh ralph sudo -n systemd-creds
decrypt --name=nzbgeek /etc/homelab/nzbgeek.cred`).

## Decision

`geek_key` now falls back, in order: local systemd-creds → `ssh ralph` systemd-creds
→ `pass show`. The `pass` fallback stays but is no longer on the path from Jason.

## Why

- Keeps the rule "never a plain file": the key never lands on Jason's disk.
- Makes `pass` optional for the download pipeline, so a locked `pass` store never
  blocks media downloads. `gpg-agent` was also configured with
  `allow-preset-passphrase` and `max-cache-ttl 0` for a future one-time unlock,
  but nothing here depends on it.

## Related

- `scripts/nzb-dl.sh` (`geek_key`), `docs/media/README.md`, `docs/security/README.md`
- Pulp Fiction queued as NZBGet job 183 (Movies category).
