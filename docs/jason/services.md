# Jason — services, timers and scheduling

The part `packages.md` cannot show: what runs on a schedule, what starts at boot,
and which units exist **without** a package behind them. Evidence: `systemctl
list-unit-files`, `systemctl --user list-unit-files`, `list-timers`, `/etc/cron*`,
`/var/spool/cron`, and `pacman -Qo` on every unit file.

## Scheduling: there is no cron

`cronie` is **not installed**, `/etc/crontab` does not exist, `/etc/cron.hourly` is
empty, and there are no user crontabs. Everything scheduled on this box is a
**systemd timer** — so "keep the cron jobs" means keeping the timers below (and the
only cron job in the house is on Ralph, not here).

| Timer | Schedule | What it does | Verdict |
|---|---|---|---|
| `protondrive-backup.timer` (system) | weekly, `Persistent=true` | `/home/andy/services/protondrive-weekly.sh` → uploads **`/mnt/storage/backup`** to Proton Drive | **keep** — but see the trap below |
| `protondrive-documents.service` (system) | `Restart=always` | `/home/andy/services/protondrive-documents.sh` → `~/Documents` to Proton Drive, skips when nothing changed | **keep** |
| `snapper-cleanup.timer` (system) | daily/weekly per config | prunes snapshots | **keep** |
| `systemd-tmpfiles-clean.timer` | daily | `/tmp` hygiene | keep |
| `plocate-updatedb.timer`, `man-db.timer` | daily | locate/man indexes | keep |
| `archlinux-keyring-wkd-sync.timer` | daily | keyring refresh | keep |
| `shadow.timer` | daily | account ageing | keep |
| `homelab-health.timer` (**user**, `~/.config/systemd/user/`) | `*-*-* 08:00:00`, `Persistent=true` | `scripts/homelab-health.sh` from this repo | **keep** — it is yours |

### `/mnt/storage`

1. `protondrive-weekly.sh` uploads `/mnt/storage/backup`. Reformat that disk without
   touching the script and the weekly backup starts failing silently-ish (it will
   exit non-zero, and there is no notification daemon to say so).
2. `/etc/exports` serves `/mnt/storage` over NFS to **Tom** (`192.168.1.24`,
   `192.168.1.23`), and `nfs-server.service` is enabled — the reformat needs the
   export re-created and re-exported, or Tom loses its mount.

Both are one-line changes, but they belong in the migration checklist, not in
"later".

## System units enabled

| Unit | Why | Verdict |
|---|---|---|
| `NetworkManager.service` + `-dispatcher` | one network manager, wifi mgmt | keep |
| `systemd-resolved`, `systemd-timesyncd` | DNS + time | keep |
| `systemd-oomd` | OOM handling | keep |
| `tailscaled` | tailnet, how Tom and Ralph are reached | keep |
| `ufw` | firewall | keep |
| `proton.VPN.service` | Proton VPN daemon | keep |
| `sddm` | login | keep |
| `docker.socket` | containers on demand | keep |
| `snapper-cleanup.timer`, `limine-snapper-sync.service` (+ `limine-snapper-watcher`) | snapshots and their boot entries | keep — **AUR** packages, see `whitelist.md` |
| `linux-modules-cleanup.service` (`kernel-modules-hook`) | drops module trees for removed kernels | keep |
| `nfs-server.service` | exported `/mnt/storage` to Tom | **dropped 2026-11-11** — nothing consumes it |
| `power-profiles-daemon` | power profiles | keep |
| `getty@.service` | a real TTY when the GUI is dead | keep |
| `avahi-daemon` (+ socket) | `.local` name resolution via `nss-mdns` | keep — free, and name resolution is the sort of thing you want when debugging |
| `bluetooth.service` | no paired devices, `bluez` stack dropped | **drop** |
| `cups.service` / `cups.socket` / `cups.path` | printing was declared unwanted | **drop** with `cups*` |

## Custom units with no package behind them

These are hand-written. They now live in the repo, with the scripts that run them:
[`services/jason/`](../../services/jason/) (README there covers deploying and
repointing the units).

| Unit | Runs | Verdict |
|---|---|---|
| `protondrive-documents.service` | `~/services/protondrive-documents.sh` | keep |
| `protondrive-backup.service` + `.timer` | `~/services/protondrive-weekly.sh` | keep |
| `qbittorrent.service` | `qbittorrent-nox --confirm-legal-notice` | **delete** — see below |
| `limine-snapper-watcher.service` | alias → `limine-snapper-sync.service` | keep (repo package, AUR replacement) |

### qBittorrent on Jason: a leftover to clean up

It should not be here, and it is not a "maybe": the torrenting lives on Ralph
(`qbittorrent-nox@qbittorrent`, the packaged template unit,
[`../ralph/README.md`](../ralph/README.md)). What Jason still carries:

| Leftover | Evidence |
|---|---|
| `qbittorrent-nox` 5.3.0 package | binary last read **2026-11-08** |
| `/etc/systemd/system/qbittorrent.service` (hand-written, `--confirm-legal-notice`) | `disabled`, `inactive` — it exists only because it was written by hand |
| `~/.config/qBittorrent/` | `qBittorrent.conf`, `categories.json`, `rss/`, from **2026-10-21**; no WebUI password or API key stored in it |
| `~/.local/share/qBittorrent/` | **8 MB** of session data; `~/Downloads` is empty |

Cleanup when convenient: `sudo systemctl disable --now qbittorrent.service`,
`sudo rm /etc/systemd/system/qbittorrent.service && sudo systemctl daemon-reload`,
`pacman -Rns qbittorrent-nox`, then `rm -rf ~/.config/qBittorrent
~/.local/share/qBittorrent`.

`~/services` was its own git repo (`andrew-a-hale/services`) with the units in
`/etc/systemd/system` — two places, neither of them this repo. Both scripts and the
unit files are now copied to [`services/jason/`](../../services/jason/), which is the
source of truth; the old directory can be archived once the units are repointed
(migration step in that README). Nothing secret is in either copy: credentials come
from `PASSWORD_STORE_DIR=/home/andy/.password-store-proton`, and the repo is public.

## User units enabled

| Unit | Why | Verdict |
|---|---|---|
| `pipewire.service`, `pipewire-pulse.service` (+ sockets), `wireplumber.service` | audio | keep |
| `gnome-keyring-daemon.socket`, `p11-kit-server.socket` | keyring / secrets for git, ssh, apps | keep |
| `xdg-user-dirs.service` | `~/Documents` etc. | keep |
| `homelab-health.timer` | your own 08:00 health check | keep |
| `omarchy-fcitx5.service` | starts the IME | **drop** → `exec-once` in the Hyprland config |
| `omarchy-sleep-lock.service` | locks on sleep | **drop** → `hypridle`'s `before_sleep_cmd` |
| `omarchy-crash-watch.service` | watches for Omarchy crashes | **drop** — no Omarchy |
| `omarchy-migrate-notify.service` | migration notices | **drop** |
| `omarchy-recover-internal-monitor.service` | laptop display recovery | **drop** — desktop, no internal panel |
| `owed.service` | video wallpaper daemon | **drop** — `hyprpaper` instead |
| `bt-agent.service` | bluetooth agent | **drop** with bluetooth |

## What this adds up to

12 system units kept (4 of them with migration caveats), 2 dropped; 7 user units
kept, 6 dropped with a named replacement or nothing; 8 timers kept, 0 dropped; no
cron anywhere. The two things that must be handled *during* the migration, not after:
`protondrive-weekly.sh`'s `/mnt/storage/backup` path. No NFS export to re-create:
Tom does not need one.

## Tom's mount: removed (2026-11-11)

Verified after cleanup: `mount | grep storage` → nothing, `/etc/fstab` is down to
its three system lines with no NFS entry, `/mnt/storage` is an empty root-owned
directory. Tom has no reference to `/mnt/storage` anywhere in its user crontab or
`/home/tom`. NFS is gone from both ends: Jason exports nothing, `nfs-server` is
inactive, port 2049 closed.
