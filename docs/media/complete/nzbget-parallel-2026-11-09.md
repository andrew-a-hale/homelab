# NZBGet on Ralph, parallel to qBittorrent (2026-11-09)

## Task

Follow-on from [`../todo/usenet-vs-torrents-2026-11-09.md`](../todo/usenet-vs-torrents-2026-11-09.md):
"set this up similarly to qBittorrent, we can run both in parallel in case we
need something we can't find in the other."

So: a second downloader, same exposure shape as `/bt/`, no provider account yet
(that is Andy's purchase; the login went into `pass` as `homelab/xsnews`).

## What was done (on Ralph, 2026-11-09)

```
pacman -S nzbget par2cmdline 7zip unrar      # nzbget 26.3-1, in extra
useradd --system --user-group --home-dir /var/lib/nzbget --shell /usr/bin/nologin nzbget
install -d -o nzbget -g nzbget -m 775 /var/lib/nzbget /srv/media/downloads
install -o nzbget -g nzbget -m 600 /usr/share/nzbget/nzbget.conf /var/lib/nzbget/nzbget.conf
usermod -aG jellyfin nzbget
systemctl enable --now nzbget
```

Config keys changed from the shipped template (`/var/lib/nzbget/nzbget.conf`):

| Key | Value | Why |
|---|---|---|
| `MainDir` / `DestDir` | `/srv/media/downloads` / `${MainDir}/complete` | same filesystem as the library → finished jobs are a `rename`, not a 15GB copy |
| `Category1.DestDir` / `Category2.DestDir` | `/srv/media/movies` / `/srv/media/tv` | drop straight into Jellyfin's libraries, like qBittorrent's save paths |
| `AppendCategoryDir` | `no` | otherwise it nests `movies/Movies/...` and Jellyfin scans one level too deep |
| `ControlIP` / `ControlPort` | `127.0.0.1` / `6789` | never `0.0.0.0`; nginx is the only door |
| `AuthorizedIP` | `127.0.0.1` | loopback requests skip the WebUI login, so there is exactly **one** password prompt (nginx's) instead of two |
| `Server1.Active` | `no` | no account yet; the daemon idles with `No servers are configured` |
| `UMask` | `0022` | files `644`/dirs `755` owned by `nzbget`, so Jellyfin reads them without a chown dance |
| `ArticleCache` / `WriteBuffer` | `200` / `1024` | the two warnings it prints on first start; Ralph has 16GB to spare |

nginx `conf.d/ralph.conf` gained an `/nzb/` block that is a copy of `/bt/`:
`if ($http_cf_ray) { return 404; }`, `auth_basic` against the same
`/etc/nginx/htpasswd`, `proxy_pass http://127.0.0.1:6789/`, plus
`client_max_body_size 100m` for `.nzb` uploads of very large posts.

Also updated: `scripts/homelab-health.sh` (`nzbget` added to `RALPH_UNITS` and
the remote probe), `RUNBOOK.md` (package line, useradd trap, nginx map, recovery
bullet, secrets table), `docs/ralph/nginx-ralph.conf` (the repo copy is the
rebuild source of truth), `docs/media/README.md`.

## Decisions and why

- **Parallel, not replacement.** Fresh releases still leak to torrents first and
  takedowns hit usenet hard; back catalogue is the opposite. Keeping both costs
  one idle daemon and one `pacman` package. Retiring qBittorrent is a separate
  decision with a separate prize (deleting `wg-quick@proton0` and
  `proton-guard.timer`), so it stays a separate decision.
- **NZBGet over SABnzbd.** `extra/nzbget 26.3-1` is the current upstream release
  (v26.3, 2026-08-27) and ships a unit that already runs as an unprivileged user
  with `Restart=on-failure`. SABnzbd is not in the Arch repos: AUR or a pip venv
  plus a hand-written unit. Rung 5 of the ladder — take the packaged one.
- **Its own port and its own path, same auth.** Reusing `/nzb/` shape means the
  existing `nginx-http-auth` fail2ban jail (already enabled in `jail.local`)
  covers it for free, and no new jail, filter, or firewall rule is needed.
  Nothing new listens on the LAN or the WAN: `127.0.0.1:6789` + nginx.
- **`AuthorizedIP=127.0.0.1` instead of a WebUI password.** The box is
  single-user and nginx already gates `/nzb/`; a second password prompt buys
  nothing against an attacker who is already on loopback. This is the one place
  the qBittorrent shape is *not* copied — qBittorrent keeps its own login, and
  that is fine too, it just costs two prompts.
- **`nzbget` user created by hand.** The Arch package ships no `sysusers.d`
  entry while its unit says `User=nzbget`, so `systemctl start` fails with
  `invalid user` on a fresh box. Recorded in `RUNBOOK.md` because it will bite
  the next rebuild otherwise.
- **No VPN binding.** TLS to a paid provider, no peers, no swarm. `proton0`
  stays qBittorrent's concern (`../../../docs/vpn/README.md`).

## Verified (2026-11-09, on Ralph)

```
ss -ltnp | grep 6789            → 127.0.0.1:6789        (loopback only)
curl 127.0.0.1:6789/            → 200                   (AuthorizedIP bypass)
curl http://ralph/nzb/          → 401                   (basic auth enforced)
curl -u <htpasswd user> …/nzb/  → 200, <title>NZBGet</title>
curl … /nzb/index.js            → 200                   (relative assets proxied)
curl -u … -d '{"method":"version"}' …/nzb/jsonrpc → {"result":"26.3"}
curl -u … -H 'CF-Ray: x' …/nzb/ → 404                   (tunnel guard, like /bt/)
curl … /bt/                     → 200                   (qBittorrent untouched)
```

The authenticated checks used a throwaway `verify-tmp` htpasswd entry, which was
removed and nginx reloaded immediately after — `/etc/nginx/htpasswd` still holds
only `andy`. `journalctl -u nzbget` shows no `UnrarCmd`, `ArticleCache` or
`WriteBuffer` warnings after the restart, only the expected
`No servers are configured`.

Not verified, because it needs the account: an actual download, PAR2 repair and
the `nzbget`-owned file landing in `/srv/media/tv` with a mode Jellyfin can read.
That is the first thing to check when `Server1` goes live.

## Provider connected (2026-11-09, same day)

XS News credentials went into `pass` (`homelab/xsnews/username`,
`homelab/xsnews/password`) and were applied to
`/var/lib/nzbget/nzbget.conf` as `Server1.*`: `reader.xsnews.nl`, port 563,
`Encryption=yes`, `Connections=20`, `Level=0`, `Active=yes`, name `XS News`.
Restarted `nzbget`; the daemon logs no server line at INFO, so the proof is
behavioural, below.

### Auth is real, not just a TCP connect

NZBGet 26 health-checks a post by stat-ing every article against the provider
before downloading. Two test posts (a Twin Peaks S01E01 collection, pulled from
binsearch) came back with real availability percentages — 89.8% — which is only
possible with an authenticated NNTP session. No `Authorization failed` anywhere
in the journal.

### Takedowns are the first real-world fact about the account

That test post was cancelled before a byte was downloaded:

```
[WARNING] Cancelling download and deleting test-twinpeaks due to health 89.8% below critical 89.9%
```

`HealthCheck=park` decides the action; the ~89.9% critical threshold is not a
visible option in 26.3's config template. So a post that is 10% eaten by DMCA is
refused outright. Force it with `HealthCheck=none` if a partial is still worth
having — PAR2 will only repair the redundancy that is actually there.

### The rest of the chain, verified without a 1.4GB download

PAR2 ran for real (job 1, a deliberately partial NZB):
`par2cmdline-turbo version 1.4.0` reporting `not enough par-blocks, 2000 needed,
200 available` — the verifier works and its verdict was honest. The permission
half needs no download at all:

```
sudo -u nzbget bash -c 'umask 0022; touch /srv/media/tv/.perm-probe'
  → 644 nzbget:nzbget, and `sudo -u jellyfin head -c1` succeeds
```

So a finished job will be readable by Jellyfin without a chown. Test artifacts
were removed: history cleared, `/srv/media/downloads/complete` empty,
`/srv/media/tv` untouched.

### Left for the first real download

Throughput against the 50 Mbit cap (expect ~6 MB/s) and the unpack step on a RAR
post. Grab something actually wanted from binsearch, watch `/nzb/`, and if the
health line shows up, it is the post, not the config.

## Next

1. Andy buys a provider (XS News Basic 50, €2.95/mo annual, was the shortlist
   favourite) and puts the login in `pass show homelab/xsnews`.
2. Paste into `/var/lib/nzbget/nzbget.conf`:
   `Server1.Active=yes`, `Server1.Host=…`, `Server1.Port=563`,
   `Server1.Encryption=TLS`, `Server1.Username=…`, `Server1.Password=…`,
   `Server1.Connections=30`, `Server1.Level=0` → `systemctl restart nzbget`.
3. `http://ralph/nzb/` → Add NZB. First job confirms the unpack chain, the file
   mode, and that Jellyfin sees it.
