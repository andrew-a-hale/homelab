# Jason — services, timers and scheduling

What starts at boot and what runs on a schedule. There is **no cron** on this box:
`cronie` is not installed, `/etc/crontab` does not exist, and there are no user
crontabs — everything scheduled is a systemd timer. (The house's only cron job is
on Ralph.)

## Custom units (no package behind them)

Hand-written. Scripts live in [`services/jason/`](../../services/jason/) and the
installed units run them **from the repo path** — there is no second copy:

| Unit | Runs | Schedule |
|---|---|---|
| `protondrive-documents.service` (system) | `services/jason/protondrive-documents.sh` — `~/Documents` → Proton Drive, skips the API when nothing changed | `Restart=always`, `RestartSec=300`; "auto-restart" is its normal resting state |
| `protondrive-backup.service` + `.timer` (system) | `services/jason/protondrive-weekly.sh` — `/mnt/storage/backup` → Proton Drive | weekly, `Persistent=true` |
| `homelab-health.timer` (user) | `scripts/homelab-health.sh` from this repo | daily 08:00, `Persistent=true` |

Credentials come from a dedicated pass store
(`PASSWORD_STORE_DIR=/home/andy/.password-store-proton`); nothing secret is in the
repo. Both uploads use the Proton Drive CLI with
`-f create-new-revision -d merge`, so they never delete remote content — see
[`docs/backups/`](../backups/README.md).

Deploying a unit change: `git pull`, `sudo install -m 644
services/jason/systemd/<unit> /etc/systemd/system/`, `sudo systemctl daemon-reload`.

## Packaged units enabled

| Unit | Why |
|---|---|
| `NetworkManager.service`(+`-dispatcher`), `systemd-resolved`, `systemd-timesyncd` | network, DNS, time |
| `tailscaled` | tailnet — how Tom and Ralph are reached |
| `ufw` | firewall |
| `proton.VPN.service` | Proton VPN daemon |
| `sddm` | login |
| `docker.socket` | containers on demand |
| `avahi-daemon` | `.local` name resolution via `nss-mdns` |
| `getty@.service` | a real TTY when the GUI is dead |
| `systemd-oomd` | OOM handling |
| `power-profiles-daemon` | power profiles |
| `limine-snapper-sync.service` (+`-watcher`), `snapper-cleanup.timer` | snapshots and their boot entries (AUR packages) |
| `linux-modules-cleanup.service` | drops module trees for removed kernels |
| `systemd-tmpfiles-clean`, `plocate-updatedb`, `man-db`, `archlinux-keyring-wkd-sync`, `shadow` timers | routine hygiene |

## User units enabled

`pipewire` + `pipewire-pulse` (+ sockets), `wireplumber` (audio),
`gnome-keyring-daemon.socket` + `p11-kit-server.socket` (secrets),
`xdg-user-dirs`, `homelab-health.timer`, and — because a unit on
`graphical-session.target` is the only way they get a working `WAYLAND_DISPLAY` —
`waybar`, `hyprpaper`, `hypridle`. `hyprpaper` has a drop-in
(`config/systemd/user/hyprpaper.service.d/10-wait-for-compositor.conf`) so it
retries until the compositor socket exists.

Started from `config/hypr/autostart.lua` instead, because they ship no unit:
`fcitx5` and `udiskie`.

## Gone

`qbittorrent.service` and its config are gone (torrents live on Ralph);
`nfs-server` was never used by Tom and is gone; the `omarchy-*` and `owed` units
went with Omarchy ([record](complete/left-omarchy-2026-11-11.md)).

## `/mnt/storage`

`protondrive-weekly.sh` uploads `/mnt/storage/backup`. Reformatting that disk
without updating the script makes the weekly backup fail with no notification
daemon to say so. Nothing else reads it; there is no NFS export.
