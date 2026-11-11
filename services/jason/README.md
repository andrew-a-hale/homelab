# Jason's scheduled services

Source of truth for the scripts and systemd units that run on Jason without a
package behind them. Before this, they lived only in `~/services` (its own git repo,
`andrew-a-hale/services`) with the unit files in `/etc/systemd/system` — two places,
neither of them the homelab repo.

Nothing secret is here. Credentials come from a dedicated pass store
(`PASSWORD_STORE_DIR=/home/andy/.password-store-proton`), the repo is public.

## What runs

| Script | Unit | Schedule | What it does |
|---|---|---|---|
| `protondrive-documents.sh` | `protondrive-documents.service` (`Restart=always`) | continuous | `~/Documents` → Proton Drive, skips the API entirely when nothing changed (`~/last-sync` marker + `fd --newer`) |
| `protondrive-weekly.sh` | `protondrive-backup.service` + `protondrive-backup.timer` | weekly, `Persistent=true` | `/mnt/storage/backup` → Proton Drive `/my-files` |
| `pass-sync.py` | none | one-off | imports a `pass.csv` export into `pass`; kept for the record, prints passwords to stdout — do not leave it on a timer |

Both uploads use the official Proton Drive CLI at `~/.local/bin/proton-drive` with
`-f create-new-revision -d merge`, i.e. they never delete remote content (that was
the rclone behaviour that kept dying on stale 2FA tokens — see
`docs/backups/README.md`).

qBittorrent is **not** a Jason service and is deliberately not in this repo: it runs
on Ralph, from the packaged `qbittorrent-nox@.service` template. Jason still carries
the leftovers of the October experiment (package, a hand-written unit, config, 8 MB
of session data) — see `docs/jason/services.md` for the cleanup. Its config is not
copied here or anywhere else.

## Deploying a change

```bash
# on Jason, after committing and pushing from wherever
cd ~/projects/homelab && git pull
sudo install -m 644 services/jason/systemd/protondrive-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
systemctl list-timers protondrive-backup.timer
```

## Migration off `~/services` — done 2026-11-11

The installed units used to run `/home/andy/services/…`. Repointed to
`/home/andy/projects/homelab/services/jason/…` and reloaded:

```bash
sudo sed -i 's|/home/andy/services/|/home/andy/projects/homelab/services/jason/|' \
  /etc/systemd/system/protondrive-documents.service \
  /etc/systemd/system/protondrive-backup.service
sudo systemctl daemon-reload && sudo systemctl restart protondrive-documents.service
```

Verified afterwards: `protondrive-documents.service` exits `0/SUCCESS` from the new
path and cycles on `Restart=always`/`RestartSec=300` (it is a poll loop, so
"activating (auto-restart)" is its normal resting state between runs);
`protondrive-backup.timer` next fires Mon 2026-11-16, last ran Mon 2026-11-09.

The old tree is parked at `~/services.retired-2026-11-11` (its own git repo,
`andrew-a-hale/services`) — delete it once a week has passed without needing it.
