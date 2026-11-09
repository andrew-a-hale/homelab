# Usenet instead of torrents — investigation (2026-11-09)

TODO: "Investigate usenet instead of torrents". This is the investigation, not
a decision: nothing is installed, nothing is paid for. Facts about this house
were measured on Ralph 2026-11-09; facts about providers/indexers are from
published 2026 pricing pages and are the volatile half.

## What the current setup actually costs us

qBittorrent 5.3.0 on Ralph, interface-bound to `proton0`, WebUI on
`127.0.0.1:8081` behind nginx `/bt/` basic auth (`../README.md`). Downloads are
**manual**: find a `.torrent` yourself, drop it in the WebUI.

Four pieces of standing work exist only because it is torrents:

| Cost | Detail |
|---|---|
| A VPN for one app | `wg-quick@proton0` + `proton-guard.timer` every 5 min + uid policy routing (`../vpn/README.md`) |
| A failure mode | tunnel drops → downloads stop, and we have debugged exactly that (`../ralph/complete/qbittorrent-vpn-2026-11-07.md`, `../media/complete/twin-peaks-stalled-vpn-interface-2026-10-23.md`) |
| Peer dependence | a torrent with 2 seeders stalls, needs a seeder awake, seeds forever after |
| Library shape | 63G total (`/srv/media`: 16G movies, 47G tv, 3.5T free) |

## What usenet is, in one paragraph

Articles on a set of commercial servers, kept for years, fetched by `NNTP`
over TLS from one host. The user never talks to peers. An `.nzb` file is just
an index of message-ids for one post; a downloader (NZBGet/SABnzbd) pulls the
articles, PAR2-verifies and -repairs, then unpacks. No swarm, no seeding, no
ratio, and full speed from the first byte because there is exactly one server
to ask.

## Where it wins here

- **No peers, so no leak vector.** The protocol is TLS client→server. The
  reason `proton0` exists (hide peer IPs from the swarm) simply does not arise.
  That is not "more private" overall — the provider knows your account and your
  IP — but it removes the whole class of bug we keep fixing.
- **No VPN for downloads.** `wg-quick@proton0` + `proton-guard.timer` +
  `Table=off` uid routing stop being load-bearing for the media pipeline. Keep
  them if qBittorrent stays; a lot of the "VPN is down so the download is stuck"
  surface disappears if it doesn't.
- **Retention.** Omicron-backed providers (Newshosting, Eweka, UsenetServer,
  Tweaknews, Easynews) advertise ~5,900 days ≈ 16 years. Old TV and obscure
  films that are dead torrents are still there.
- **Saturates the link unattended.** No seeding, so a finished download is
  finished.
- **Downloads resume/retry server-side.** Missing articles get PAR2-repaired
  from redundancy, not by waiting for a seeder to reappear.

## Where it loses

| Cost | Detail |
|---|---|
| Money | Provider ~US$6–13/mo unlimited (Newshosting Unlimited US$12.95/mo, ~US$5.99/mo annual on the deals that are always running; UsenetServer ~US$7.95/mo on 12 months, VPN bundled). Indexer NZBGeek ~US$12/yr, lifetime ~US$40–80; DrunkenSlug is invite-only, €5–20/yr |
| DMCA takedown | Providers remove articles on notice. Popular new releases can be gutted days after posting; obfuscation helps but the fix is a second provider/backbone, i.e. more money |
| Not anonymous | One paid account, your IP, your card, and the login in your password store. Different tradeoff from "VPN-bound torrent client", not strictly better |
| Two accounts, two renewals | Provider *and* indexer both expire, and both silently degrade the moment they do |
| Nothing upstream of the downloader | Usenet has no search of its own that is worth using — the indexer is the search |

Legal note, plainly: in Australia, downloading copyrighted material without
the rightsholder's permission is infringement regardless of protocol, and
usenet providers honour takedown notices as readily as torrent sites do. The
protocol changes the engineering, not the law.

## Local facts (measured, 2026-11-09, Ralph)

```
$ pacman -Ss nzbget      → extra/nzbget 26.3-1
$ pacman -Si sabnzbd     → error: package 'sabnzbd' was not found
$ pacman -Fl nzbget      → usr/bin/nzbget, usr/lib/systemd/system/nzbget.service
$ df -h /srv/media       → /dev/sda1 3.6T, 62G used, 3.5T avail
```

- **NZBGet is in `extra` and current**: 26.3-1 in the repo, 26.3 released
  upstream 2026-08-27 (`nzbgetcom/nzbget`, actively maintained again after the
  long 21.x freeze). One `pacman -S`, no AUR, no pip venv.
- **SABnzbd is not in the repos** → AUR or a pip venv plus a hand-written unit.
  It has the nicer UI and the bigger add-on ecosystem; NZBGet has the shorter
  path to running on this box.
- The shipped unit is already sane and unprivileged:
  `User=nzbget`, `Group=nzbget`, `WorkingDirectory=/var/lib/nzbget`,
  `ExecStart=/usr/bin/nzbget -s -c /var/lib/nzbget/nzbget.conf …`,
  `Restart=on-failure`. The package ships **no** config — the first run writes
  `/var/lib/nzbget/nzbget.conf` from the template.
- Nothing else is needed on Ralph: no Docker (`docker ps` → nothing installed;
  Jellyfin, qBittorrent, nginx all run under systemd here), and no *arr apps
  today (`pacman -Qq | grep -i 'sonarr\|radarr\|sab\|nzb\|prowlarr'` → empty).

## The install, if it happens

Deliberately the same shape as qBittorrent, because that shape is already
proven and already firewalled:

1. `sudo pacman -S nzbget`; put the NZBGet WebUI on loopback only
   (`ControlIP=127.0.0.1`, `ControlPort=6789`), never `0.0.0.0`.
2. nginx `/nzb/` reverse proxy + basic auth, mirroring `/bt/` — password in
   `pass show homelab/qbittorrent` (one credential covers `/bt/` and `/nzb/`), fail2ban jail copied from `qbittorrent`. Not in the tunnel
   config, so it stays LAN/tailnet only.
3. `MainDir=/srv/media/downloads`, `DestDir` → `/srv/media/movies` and
   `/srv/media/tv`, user `nzbget` added to the `jellyfin` group, or the files
   land root-owned and Jellyfin cannot read them.
4. Provider details in `/var/lib/nzbget/nzbget.conf` (`Server1.Host/.Port=563/
   .Encryption=TLS/.Username/.Password`, `Server1.Connections=20–30` — the
   provider sells 100, Ralph's wifi does not need them). Secret stays out of
   this repo, same rule as `/etc/wireguard/proton0.conf`.
5. Verify: `curl -s -o /dev/null -w '%{http_code}\n' -u user:pass http://ralph/nzb/`,
   `ss -ltnp | grep 6789` → `127.0.0.1` only, one test NZB arrives complete in
   `/srv/media/tv`, Jellyfin sees it.

I have **not** touched Ralph beyond `pacman -Syw` (download-only, so the
`nzbget.service` unit could be read out of
`/var/cache/pacman/pkg/nzbget-26.3-1-x86_64.pkg.tar.zst`). Nothing installed,
nothing enabled.

## Recommendation

Buy the two accounts before installing anything — a week of a provider trial
plus NZBGeek's cheap tier answers the only question that matters (does it find
what we actually watch?) for the price of a coffee. If yes, `pacman -S nzbget`
on Ralph is a 30-minute job with the steps above.

Keep qBittorrent for a month after that. Torrents still win for very new
releases and for anything the takedown bots ate. Delete it only when the usenet
path has not been opened in a month — that is also when `wg-quick@proton0` and
`proton-guard.timer` can go, which is the actual prize here: one fewer
always-on tunnel on the gateway.

Skipped on purpose: **Sonarr/Radarr/Prowlarr automation.** It is the real
quality-of-life jump, but it is a separate decision, a separate TODO, and it
works the same whether the downloader is torrent or nzb. Adding it now would
mean debugging a stack we have not decided to keep.

## Free providers and free indexers (asked 2026-11-09)

Short answer: **indexers yes, providers no.** No permanent free binary provider
exists; that is not a gap we can engineer around, it is the business model.

### Providers

| Option | Free? | Ceiling |
|---|---|---|
| `news.eternal-september.org` | yes, no time limit, registration | **text groups only**, no binaries at all — useless for media |
| Usenet.Farm 10GB tier | yes, no card, no time limit | 10GB total ≈ 4–5 1080p films, then it is done forever on that account |
| Newshosting / UsenetServer / Eweka trials | 14 days, ~30GB | enough to answer "does it find what we watch", nothing more |
| Google Groups | — | text only, and the binary hierarchy has been gone for years |

Retention and speed are what the money buys: the free tiers keep days of
articles at best, and 10GB does not build a library (ours is 63G).

### Indexers

These are genuinely free, ad-supported, and **verified answering today**
(2026-11-09, HTTP 200 from Jason):

| Indexer | Free limits |
|---|---|
| `binsearch.info` | free search, generous retention for plain posts, no API, captcha-prone |
| `nzbindex.com` | free search, rate-limited, redirects to `/search` |
| `nzbking.com` | free search, no API |

What they cannot do: decode **obfuscated** posts (the newer, takedown-resistant
ones read as random gibberish — paid indexers map them back to titles), give an
API for automation, or survive heavy polling. They are browser search boxes,
not indexer endpoints for Prowlarr.

### The $0 path, and why it is still a bad deal here

Usenet.Farm's 10GB + binsearch + NZBGet works end to end, and the workflow is
identical to torrents today: search in a browser, download the `.nzb`, drop it
in the NZBGet WebUI (`add by file/URL`). No API needed.

It also stops after 10GB. A quarter of our current TV library, once, ever. The
$6/mo provider is cheaper than one streaming subscription and it is the only
part of this pipeline that is genuinely not free. The indexer is the cheap half
(~$12/yr) and the free ones cover a trial fine — start with binsearch, buy
NZBGeek only if search quality frustrates you.

## What was actually installed (2026-11-09)

NZBGet 26.3 is now on Ralph in parallel with qBittorrent, shipped shape and all:
`/nzb/` behind the same nginx basic auth + `CF-Ray` guard as `/bt/`, WebUI on
`127.0.0.1:6789`, categories writing straight into `/srv/media/{movies,tv}`.
Idle until a provider account exists (`Server1.Active=no`).

- Install + decisions: [`../complete/nzbget-parallel-2026-11-09.md`](../complete/nzbget-parallel-2026-11-09.md)
- What is left is the account: XS News Basic 50 (€2.95/mo annual, 50 Mbit/s,
  4,000+ days) plus a free indexer is the €35/yr version of this whole idea.

## Open questions (owner: Andy)

1. Provider: Newshosting (cheapest reliable, US, 100 conn, 5,900 days) vs
   Eweka (Dutch backbone, better completion for some European posts) vs
   UsenetServer (~US$7.95/mo, VPN bundled — the VPN is redundant here).
2. Monthly budget: one provider only (~US$6–13/mo), or a second backbone for
   completion (~US$3–5/mo more)?
3. Keep qBittorrent alongside, or replace it outright?
4. Want the *arr automation as a follow-up ticket, or stay manual (find an
   `.nzb`, drop it in the WebUI)?

Sources: tomsguide.com/best-picks/the-best-usenet-providers,
datahoarder.io/best-usenet-providers (prices checked Sept 2026),
usenet.com/nzbgeek-review, usenet.com/drunkenslug-nzb-review,
github.com/nzbgetcom/nzbget/releases (v26.3, 2026-08-27). Prices move; re-check
before paying.
