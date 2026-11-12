# Jason's scheduled services

Source of truth for the scripts and systemd units that run on Jason without a
package behind them. The installed units run these scripts **from this repo path**
— there is no second copy and no `~/services` tree.

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

qBittorrent is **not** a Jason service and is not in this repo: it runs on Ralph,
from the packaged `qbittorrent-nox@.service` template. Jason's October leftovers
(package, hand-written unit, config, session data) were removed 2026-11-12.

## Deploying a change

```bash
# on Jason, after committing and pushing from wherever
cd ~/projects/homelab && git pull
sudo install -m 644 services/jason/systemd/protondrive-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
systemctl list-timers protondrive-backup.timer
```

Deployment is done — units load from
`/home/andy/projects/homelab/services/jason/…` since 2026-11-11.
