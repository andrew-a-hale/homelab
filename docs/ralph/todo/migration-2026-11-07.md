# Ralph migration: what moves off Tom (2026-11-07)

**Status:** planning. Ralph is installed, encrypted, Guix-installed, with a
3.6T ext4 media drive at `/srv/media`. Nothing has moved yet.

## Inventory of Tom (Debian, Pi 5, aarch64, 29G SD card, 74% full)

| Thing | Where it lives now | Notes |
|---|---|---|
| Jellyfin | `jellyfin.service`, port 8096 | config `/var/lib/jellyfin` (95M), libraries: `/mnt/storage/media/{movies,tv}` |
| Media | **Ralph** `/srv/media` (was Jason `192.168.1.181:/mnt/storage` over NFS4 — copy verified by checksum and the Jason copy deleted 2026-11-07; `backup` (389M) remains there and the NFS export stays) | 59G total: 12G movies, 47G tv, 61 files |
| nginx | `:80`, single `sites-enabled/default` | proxies `/jf/` → 8096, `/bt/` → 8081 with basic auth |
| qBittorrent | `qbittorrent-nox@tom`, `:8081`, bound to `10.2.0.2` | Proton VPN split-tunnel, leak protection via interface binding |
| Proton VPN | `me.proton.vpn.split_tunneling.service` | plus `/usr/local/bin/cloudflared-bypass.sh` to route cloudflared over the bare ISP |
| Website | Go binary `andrewahale.com` on `127.0.0.1:8080` | **not proxied by nginx** — nginx has no vhost for it |
| Cloudflare tunnel | **not on Tom** | nothing named cloudflared is running here; only the bypass script exists |
| Tailscale | `tailscaled`, tailnet `tail8455e6.ts.net`, `tom` = 100.77.132.110 | also `jason` 100.95.54.82, `iphone-11` |
| Petcam | `/home/tom/petcam` | **stays on Tom** |
| Health cron | `*/2` → `logger -t tom-health` (throttled flags, temp, 5V) | exists because of Tom's brownout/reboot history |

## The transfer problem (measured, not guessed)

- Jason's NFS read from Tom: **fast** (16MB in 0.19s, i.e. it is not the disk).
- Raw Tom → Ralph over wifi: **0.74 MB/s** (16MB of `/dev/zero` in 21.6s).
- 16MB of real media Tom → Ralph: 0.43 MB/s.
- Jason pings from Ralph in 8ms but **ports 22 and 2049 are filtered** for Ralph —
  Jason trusts Tom only, so a direct NFS pull is blocked.

Consequence: relaying 59G through Tom over wifi is ~22 hours. Don't.

**Chosen path: sneakernet via a USB stick.** The media drive stays in Ralph; a
USB stick goes to Jason, gets 59G copied onto it, and comes back. No network, no
firewall change, no Jason login from this side.

```bash
# on Jason, stick plugged in:
lsblk -f                       # find the stick + its filesystem, needs >= 64G free
rsync -rlt --info=progress2 --no-perms --no-owner --no-group \
      /mnt/storage/media/ /run/media/$USER/<LABEL>/
sync
# then carry it to Ralph, plug in, and:
mount /dev/sdX1 /mnt/usb && rsync -a /mnt/usb/ /srv/media/ && umount /mnt/usb
chgrp -R jellyfin /srv/media
```

A FAT32 stick cannot hold the 5.6G Barry Lyndon file; exFAT, NTFS or ext4 are
fine. Ralph has `exfatprogs`, `ntfs-3g` and `udisks2` installed, plus the kernel
`exfat`/`ntfs3` modules, so any of those mount.

Rejected: changing Jason's exports/firewall (needs the runner, and AGENTS.md says
Jason is reached only that way, so it is not a drive-by change), and a 22-hour
wifi relay.

**The real lesson:** Ralph is the always-on server and it is on wifi, in the same
house that has a documented history of wifi wedges on Tom. Ralph should be wired.

## Phases

### 1. Media onto Ralph — DONE
59G via USB stick, see
[`../complete/media-and-jellyfin-2026-11-07.md`](../complete/media-and-jellyfin-2026-11-07.md).
Jellyfin is installed and its config migrated too. The Jason source copy was
verified file-by-file against Ralph (`rsync -c`, 61/61 identical) and deleted
2026-11-07; only `/mnt/storage/backup` remains on Jason.

### 2. Jellyfin on Ralph — DONE (pending a human playback test)
`extra/jellyfin-server` + `jellyfin-web` + `jellyfin-ffmpeg`, 12.4, config migrated
from Tom (same version), libraries resolving through the `/mnt/storage/media →
/srv/media` symlink. BaseUrl is `/jf`, so it answers at `/jf/` and not at root.
Jellyfin is in Arch's official repos now, so the AUR/Docker question is moot, and
Guix has no Jellyfin at all — services belong to the distro anyway. Details and
the three sharp edges: [`../complete/media-and-jellyfin-2026-11-07.md`](../complete/media-and-jellyfin-2026-11-07.md).

### 3. nginx + the Go website
nginx on Ralph with the same `/jf/` and `/bt/` shape. The Go site's
`127.0.0.1:8080` needs a vhost *somewhere* — it currently has none on Tom, so
find what actually serves `andrewahale.com` before moving it.

### 4. qBittorrent + Proton VPN
The fiddly one. Tom has: interface-bound qBittorrent (`10.2.0.2`), a split-tunnel
systemd unit, a cron health check that keeps the VPN up so torrents fail closed
rather than leaking, and the cloudflared bypass script. All of that is
Proton-specific and re-implementing it on Arch is a real task, not a copy.

### 5. Cloudflare tunnel cutover
**Correction to an earlier note in this file: cloudflared IS on Tom.** It is
launched from cron (`cgroup: /system.slice/cron.service`), not systemd, and its
ingress is locally managed in `~/.cloudflared/config.yaml`. The tunnel, its
ingress table, the petcam coupling and the DHT-sensor coupling are all written up
in [`public-ingress-2026-11-07.md`](public-ingress-2026-11-07.md).

### 6. Tailscale
`tailscale up` on Ralph, join `tail8455e6.ts.net`, then update whatever uses the
`tom` name.

### 7. Demote Tom
Stop jellyfin, qbittorrent, proton **and nginx**; keep petcam, ssh and the
health cron. Playback on Ralph verified by a real watch (Kokuho, 2026-11-07).
Petcam became a standalone app on Tom (tailnet bind, Ralph nginx in front) so
Tom no longer needs a web server at all — see
[`../petcam/complete/standalone-app-2026-11-07.md`](../../petcam/complete/standalone-app-2026-11-07.md).
Then Tom's hourly hard-reset matters a lot less.

## Open decisions

1. **Where does cloudflared actually run?** Not on Tom. Needed before any cutover.
2. **When can Ralph be wired?** Not soon. Until then every large file transfer
   and every Jellyfin stream crosses the same 0.74 MB/s wifi link that Tom →
   Ralph measured, so watch this if playback stutters.
