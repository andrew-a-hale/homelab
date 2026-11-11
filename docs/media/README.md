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
| NZBGet 26.3 | **Ralph**, `nzbget.service` | WebUI `127.0.0.1:6789`, `/srv/media/downloads`, idle until `Server1` has a provider |
| Download path | `/srv/media/movies`, `/srv/media/tv` | Jellyfin scans on start and ~30 min |

## Access

| From | URL | Auth |
|---|---|---|
| LAN | `http://ralph/jf` | Jellyfin login |
| Internet | `https://jellyfin.andrewahale.com` | Jellyfin login (no Cloudflare Access — see `../security/complete/public-ingress-2026-11-08.md`) |
| LAN (qBittorrent) | `http://ralph/bt/` | nginx basic auth; not reachable through the tunnel (`/bt/` returns 404 for tunnel traffic); the password is `pass show homelab/qbittorrent` (never in this repo). fail2ban bans a LAN client after 5 bad attempts (it cannot ban internet clients: `/bt/` is not tunnelled, so this is fine) |
| LAN (NZBGet) | `http://ralph/nzb/` | same basic auth file and the same `CF-Ray` 404 guard as `/bt/`, so the existing `nginx-http-auth` fail2ban jail covers it. NZBGet asks for nothing itself: `AuthorizedIP=127.0.0.1` means only nginx can reach it |

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

## Usenet (parallel, 2026-11-09)

NZBGet runs **alongside** qBittorrent, not instead of it: torrents keep the
library current for fresh releases, usenet covers the back catalogue that has no
seeders left. Why it exists at all, what it costs, and the free-indexer question:
[`todo/usenet-vs-torrents-2026-11-09.md`](todo/usenet-vs-torrents-2026-11-09.md);
the install decisions: [`complete/nzbget-parallel-2026-11-09.md`](complete/nzbget-parallel-2026-11-09.md).

| | |
|---|---|
| Unit | `nzbget.service`, runs as the `nzbget` system user (created by hand — the package ships no sysusers entry) |
| Config | `/var/lib/nzbget/nzbget.conf`, 600 `nzbget:nzbget`, **not in this repo** (provider password) |
| WebUI | `127.0.0.1:6789`, `AuthorizedIP=127.0.0.1`; nginx `/nzb/` is the only way in |
| Paths | `MainDir=/srv/media/downloads` (on the same filesystem as the library, so a finished job is a `rename`, not a copy), categories `Movies` → `/srv/media/movies`, `Series` → `/srv/media/tv`, `AppendCategoryDir=no` |
| Unpack/verify | `par2cmdline`, `unrar`, `7zip` from `extra`; `ArticleCache=200`, `WriteBuffer=1024` |
| Indexer | **NZBGeek**, lifetime sub, API key in `pass show homelab/nzbgeek/apikey`. Free fallbacks `--binsearch` (`binsearch.info`) and `--nzbking` (`nzbking.com`; `nzbindex.com` is client-rendered and useless for `?q=`). Geek finds re-ups the free indexers miss, which is what unblocked Avatar: The Last Airbender |
| Search | `scripts/nzb-dl.sh` — `search "query"` (NZBGeek by default), `add <id> Series|Movies`, `status`, `history`, `remove <job>`; pushes through jsonrpc over `ssh ralph`, because the WebUI is loopback-only. Edge cases and the manual fallback: `skills/usenet-download/SKILL.md` and [`complete/nzb-automation-2026-11-09.md`](complete/nzb-automation-2026-11-09.md) |
| Provider | **XS News**, configured 2026-11-09: `Server1.Host=reader.xsnews.nl`, `Port=563`, `Encryption=yes`, `Connections=20`, `Level=0`, `Active=yes`. Account login in `pass` (`homelab/xsnews/username`, `homelab/xsnews/password`) and the config copy is `/var/lib/nzbget/nzbget.conf` (600, `nzbget:nzbget`). Connections verified by NZBGet's article-availability check, not just by a TCP connect |
| Library layout | `scripts/nzb-tidy.sh` — NZBGet unpacks each job into a folder named after the release, so a finished episode lands as `tv/Avatar.The.Last.Airbender.S01E01…par2_ yEnc (1-28)/` and Jellyfin reads that as its own series. Run `./scripts/nzb-tidy.sh` after jobs finish; it files `SxxEyy` videos into `tv/<Show (Year)>/Season NN/` and deletes the emptied job dir (`complete/avatar-korra-metadata-2026-11-10.md`) |

No VPN involvement, and nothing to bind: the protocol is TLS to one paid server,
so `proton0` stays qBittorrent's problem only.

### Library layout after a usenet job

NZBGet's category `DestDir` gets a folder named after the post subject appended,
so a single-episode NZB becomes one junk folder per episode under `tv/`, and
Jellyfin turns **each of those into a separate series**: one series per episode,
and `Avatar: The Last Airbender` matched to the 2024 live-action show instead of
the 2005 animation. Nothing else is wrong with the files.

`scripts/nzb-tidy.sh` fixes it, and is the only step needed after downloads:

```bash
./scripts/nzb-tidy.sh --dry-run    # list what would move
./scripts/nzb-tidy.sh              # tidy every "… (YYYY)" folder in the library
```

It moves every video with an `SxxEyy` tag into `tv/<Show (Year)>/Season NN/<Show> - SxxEyy.mkv`,
`chown nzbget:jellyfin`, and removes the emptied job folder; Jellyfin then scans
the new paths within ~30 min (or `sudo systemctl restart jellyfin`). The show
folder has to exist first, name and year from TMDB — the year is load-bearing
here, it is what picks the 2005 Avatar over the 2024 one.

## TV

Laptop → HDMI → browser → `http://ralph/jf` → play, until a Google TV Streamer
or Shield arrives (`TODO.md`). The TV's own DLNA path is a dead end — see
[`complete/dlna-rejected-2026-11-08.md`](complete/dlna-rejected-2026-11-08.md).

## Verify

```bash
ssh ralph 'systemctl is-active jellyfin qbittorrent-nox@qbittorrent fail2ban nzbget'
ssh ralph 'sudo ss -ltnp | grep -E "6789|8081"'        # both 127.0.0.1 only
curl -s -o /dev/null -w '%{http_code}\n' http://ralph/nzb/   # 401 unauth, 200 with the htpasswd user
ssh ralph 'findmnt -T /srv/media -o SOURCE,FSTYPE,SIZE,USED,AVAIL'   # /dev/sda1 ext4
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: jellyfin.andrewahale.com' http://127.0.0.1:8096/jf/web/
curl -sI https://jellyfin.andrewahale.com/ | head -1                # 302 -> /jf/web/
ssh ralph 'sudo journalctl -u qbittorrent-nox@qbittorrent -n 20 | grep -i interface'
```

## Automation (2026-11-09)

`scripts/nzb-dl.sh` is the whole chain in one file: search NZBGeek (free
indexers as fallbacks), fetch
that post's NZB, base64 it into an NZBGet `append` over `ssh ralph` (the jsonrpc
quirks are all in the script), then `status` / `history` / `remove`. Run on Ralph
itself (where `ssh ralph` has no trusted host key) it skips the hop and curls
`127.0.0.1:6789` directly. First real
use: the Gurren Lagann series batch (`Series`) and its two films as one pack
(`Movies`), 23 GB, ~4 MB/s. Says the details:
[`complete/nzb-automation-2026-11-09.md`](complete/nzb-automation-2026-11-09.md).

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
- **Usenet costs money and dies quietly.** An expired provider or indexer looks
  identical to "this release has no sources". Takedowns are the everyday case:
  the very first test post (Twin Peaks S01E01, 1080p x265) came back **89.8%
  available** and NZBGet's health gate (`HealthCheck=park`, hidden critical
  threshold ~89.9%) parked it before a single byte was downloaded. If a post
  refuses to start, read the log for the health line before assuming a broken
  config — `HealthCheck=none` forces it through.

History: `../ralph/complete/media-and-jellyfin-2026-11-07.md` (move off Tom),
`complete/` here for the NFS era and the VPN/interface incidents.
