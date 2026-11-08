# Media server

Jellyfin + qBittorrent on **Ralph**, the always-on server. Verified
2026-11-08: library on the 3.6T USB drive, Jellyfin 12.4 serving, qBittorrent
5.3.0 downloading through the Proton tunnel.

## What runs where

| Piece | Where | Notes |
|---|---|---|
| Jellyfin 12.4 | **Ralph**, `jellyfin.service` (Arch, `pacman -Q jellyfin-server`) | `BaseUrl=/jf`, binds `0.0.0.0:8096`, UI `http://ralph/jf` |
| Library | **Ralph**, `/dev/sda1` → `/srv/media` | ext4, label `media`, 3.6T (61.8G used). `movies/`, `tv/`, `music/` (music is **not** a Jellyfin library) |
| Library path in Jellyfin | `/mnt/storage/media/...` | `/mnt/storage/media` is a **symlink to `/srv/media`** — keep it, Jellyfin's config references that path |
| Drive mount | `/etc/fstab`, `nofail,x-systemd.device-timeout=15` | plus `jellyfin.service.d/` with `RequiresMountsFor=/srv/media`, so an unplugged drive stops Jellyfin instead of serving empty libraries |
| qBittorrent 5.3.0 | **Ralph**, `qbittorrent-nox@qbittorrent` | WebUI `127.0.0.1:8081`, `Session\Interface=proton0` |
| Download path | `/srv/media/movies`, `/srv/media/tv` | Jellyfin scans on start and ~30 min |

## Access

| From | URL | Auth |
|---|---|---|
| LAN | `http://ralph/jf` | Jellyfin login |
| Internet | `https://jellyfin.andrewahale.com` | Jellyfin login (no Cloudflare Access — see `../security/complete/public-ingress-2026-11-08.md`) |
| LAN (qBittorrent) | `http://ralph/bt/` | nginx basic auth; the password is in **Proton Pass** (human credentials do not live in this repo or in `pass`). fail2ban bans a LAN client after 5 bad attempts (it cannot ban internet clients: `/bt/` is not tunnelled, so this is fine) |

The tunnel ingress points `jellyfin.andrewahale.com` **straight at
`127.0.0.1:8096`**, not through nginx, because `BaseUrl=/jf` already carries the
prefix (`../ralph/cloudflared-config.yaml`).

## Downloads

qBittorrent is **bound to `proton0`** (Proton WireGuard, `10.2.0.2`): downloads
only flow while the tunnel is up. Tunnel down = no traffic, never a leak
(`../ralph/complete/qbittorrent-vpn-2026-11-07.md`). The VPN exists for this one
app — `Table=off` and a single uid rule, so nothing else on Ralph rides it.

If qBittorrent logs "configured network interface is invalid", re-point
`Session\Interface`, `Session\InterfaceName` and `Session\InterfaceAddress` in
`/var/lib/qbittorrent/.config/qBittorrent/qBittorrent.conf` at `proton0` /
`10.2.0.2`.

## TV

Laptop → HDMI → browser → `http://ralph/jf` → play, until a Google TV Streamer
or Shield arrives (`TODO.md`). The TV's own DLNA path is a dead end — see
[`complete/dlna-rejected-2026-11-08.md`](complete/dlna-rejected-2026-11-08.md).

## Verify

```bash
ssh ralph 'systemctl is-active jellyfin qbittorrent-nox@qbittorrent fail2ban'
ssh ralph 'findmnt -T /srv/media -o SOURCE,FSTYPE,SIZE,USED,AVAIL'   # /dev/sda1 ext4
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: jellyfin.andrewahale.com' http://127.0.0.1:8096/jf/web/
curl -sI https://jellyfin.andrewahale.com/ | head -1                # 302 -> /jf/web/
ssh ralph 'sudo journalctl -u qbittorrent-nox@qbittorrent -n 20 | grep -i interface'
```

## Ceilings

- **One old drive, no redundancy** (3.6T USB), and nothing on it is backed up —
  `RUNBOOK.md` is explicit: the media is the one thing with no second copy.
  Re-rippable, not restorable.
- **No transcoding budget** — i5-9500T handles it, but every stream and every
  public request crosses Ralph's single wifi link (`../ralph/README.md`).
- **New Jellyfin plugins need `sudo systemctl restart jellyfin`** — the web UI's
  install button doesn't restart the server.
- **Manual patching.** Arch, no update timer (`../security/todo/`). Jellyfin
  12.4 is current as of 2026-11-08, and it is the box's only internet-facing
  authenticated app.

History: `../ralph/complete/media-and-jellyfin-2026-11-07.md` (move off Tom),
`complete/` here for the NFS era and the VPN/interface incidents.
