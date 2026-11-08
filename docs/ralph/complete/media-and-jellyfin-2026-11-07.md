# Ralph: media moved off Jason, Jellyfin migrated off Tom (2026-11-07)

**Date:** 2026-11-07
**Status:** done, verified server-side. **Playback not yet confirmed by a human.**
**Ticket:** [`migration-2026-11-07.md`](migration-2026-11-07.md)

59G of media and the whole Jellyfin install moved from Jason/Tom to Ralph in one
evening. This is the record of the route taken, because the obvious routes were
all blocked.

## Why the obvious routes were blocked

| Attempt | Result |
|---|---|
| Jason → Ralph over NFS (LAN) | `access denied by server` — Jason exports only Tom's IP |
| Jason → Ralph over NFS (tailnet) | same deny; :2049 is reachable over the tailnet, the export is not |
| Ralph → Jason ssh | `Connection refused` on the tailnet, filtered on the LAN |
| Jason → Tom → Ralph relay | died as a plan: Tom→Ralph wifi is **0.74 MB/s**, so 59G ≈ 22h |

Measured, in passing: Jason's NFS read from Tom is fast (16MB in 0.19s). The
bottleneck is never the disk, always a wifi hop.

## Route actually used: a USB stick

1. Jason: `mkfs.exfat`-or-ext4 stick, `rsync -rlt --no-perms --no-owner
   --no-group /mnt/storage/media/ /mnt/stick/`.
2. Ralph: mounted `/dev/sdb1` (931G WD, label `jatlas`, ext4) read-only,
   `rsync -a /mnt/usb/media/ /srv/media/`.
3. Result: **61 files, 58G, 117 MB/s, 8m53s.**

## Jellyfin

`extra/jellyfin-server 12.4` + `jellyfin-web` + `jellyfin-ffmpeg` — it is in the
official repos now, so the AUR and Docker options are both moot.

Config was migrated rather than set up fresh, because the versions matched
(12.4 on both) and that preserves users, watch state and 94M of metadata:

- `/var/lib/jellyfin` from Tom via `tar` over ssh (46s)
- `/etc/jellyfin/{database,encoding,logging*,network,system}.*` from Tom

### Three sharp edges, all hit

1. **`database.xml` silently did not copy** the first time; Jellyfin boots without
   it and you lose the DB settings. Verified by `ls`, then copied explicitly.
2. **Config ownership matters.** Files were `root:jellyfin` and Jellyfin needs to
   *write* them — it died with `FTL Access to the path '/etc/jellyfin/encoding.xml'
   is denied` after a clean-looking start. Fixed with `chown jellyfin:jellyfin`
   and mode 640.
3. **`ssh` eats the heredoc.** An inner `ssh` without `-n` consumed the rest of the
   remote script from stdin, so most of the block never ran and printed nothing.

### Path handling

Tom's libraries point at `/mnt/storage/media/{movies,tv}`. Rather than rewrite
paths inside Jellyfin's SQLite DB, `/mnt/storage/media` is a symlink to
`/srv/media`. Every indexed path resolves, no re-scan, no metadata loss, trivially
reversible. **If the library is ever re-pointed through the UI, delete the symlink.**

`BaseUrl` came over as `/jf`, so Jellyfin lives at `http://ralph:8096/jf/`, not at
the root. That matches the nginx shape Tom had (`/jf/` → 8096) and should be kept
until nginx exists on Ralph.

## Verified

- `systemctl is-active jellyfin` → active, listening 0.0.0.0:8096
- `/jf/System/Info/Public` → `ServerName: ralph`, `Version 12.4.0`,
  `StartupWizardCompleted: true`
- `GET /jf/web/` → 200
- `jellyfin.db` → **534 BaseItems** (the migrated index)
- `/srv/media` → 58G, 61 files, group `jellyfin`, `mount -a` clean

## Not done

- Human playback test (network path on wifi is the open risk)
- nginx on Ralph (`/jf/`, `/bt/`, the Go site) — DONE
- qBittorrent + Proton split tunnel — DONE, see `qbittorrent-vpn-2026-11-07.md`
- Cloudflare tunnel cutover — DONE, cloudflared runs on Ralph under systemd
- Tom demoted 2026-11-07 (jellyfin/qbittorrent/nginx/proton stopped, crons
  pruned; petcam + ssh + health/wifi-guard remain)

## Source copy on Jason deleted (2026-11-07)

After the USB transfer, the Jason source (`/mnt/storage/media`, 59G) was
verified against Ralph with `rsync -rnic` — 61/61 files checksum-identical —
then deleted. `/mnt/storage/backup` (389M) and Jason's NFS export remain; Tom
still mounts the export and nothing on it depends on `media`.

Jellyfin's libraries reference `/mnt/storage/media/{movies,tv}` and resolve
through the `media → /srv/media` symlink on Ralph — leave that symlink in place.
Both Jellyfin and qBittorrent now carry `RequiresMountsFor=/srv/media`, so a
missing USB drive (`nofail` in fstab) means they refuse to start rather than
serve empty libraries.

## Side finding: Guix on a foreign distro has no CA bundle

`guix pull` failed with `Git error: SSL error: unknown error` after 20 minutes.
Guix bundles its own TLS stack and does not use Arch's CA store. Fixed with
`/etc/profile.d/guix-certs.sh` exporting `SSL_CERT_FILE`/`GIT_SSL_CAINFO`/
`SSL_CERT_DIR` to `/etc/ssl/certs/ca-certificates.crt`. So if `guix pull` ever
fails on TLS on a fresh foreign-distro install, that is the first thing to check,
not the network.
