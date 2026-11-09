---
name: usenet-download
description: >
  Download media (or anything) over usenet with an NZB: search a free indexer,
  fetch the NZB, queue it in NZBGet on Ralph, and check it landed in Jellyfin's
  library. Use when asked to "download X with nzb", "grab X off usenet", "get
  the rest of series Y", to check on or fix a stuck NZBGet job, or when a
  download was cancelled/parked by the health check.
  Triggers: nzb, usenet, nzbget, binsearch, nzbking, "download all of X",
  par2 repair, health check, "cancelling download", dupe, category, unpack.
---

# Downloading with NZB

One script does the whole chain: `~/projects/homelab/scripts/nzb-dl.sh`
(search → fetch → queue on Ralph). This skill is the judgement around it.

## Shape of the pipeline

| Step | Where | Notes |
|---|---|---|
| Search indexer | **Jason/Ralph** (needs WAN) | `binsearch.info` primary, `nzbking.com` fallback. `nzbindex.com` is client-rendered — its `?q=` search returns no results, don't bother |
| Download the NZB | Jason/Ralph | a details id = one collection; `-L` is mandatory (binsearch 308-redirects) |
| Queue it | **Ralph**, NZBGet | `127.0.0.1:6789` only (`AuthorizedIP=127.0.0.1`) → every call is `ssh ralph curl …`. Never the WAN URL |
| Files land | Ralph | `Category=Series` → `/srv/media/tv`, `Movies` → `/srv/media/movies`, `Music`, `Software`; no category → `/srv/media/downloads/complete`, which Jellyfin never sees |
| Play | Jellyfin `http://ralph/jf` | scans every ~30 min, or restart `jellyfin.service` |

Provider is XS News over TLS (no VPN, no peers — that is qBittorrent's problem).
Measured ceiling: **~4 MB/s** (50 Mbit cap), so 23 GB ≈ 1h40. Say so, don't wait
on it.

## Use it

```bash
cd ~/projects/homelab
./scripts/nzb-dl.sh search "gurren lagann"        # id, size, age, subject
./scripts/nzb-dl.sh search "query" --nzbking      # fallback indexer
./scripts/nzb-dl.sh add <id> Series --dry-run     # fetch + validate, queue nothing
./scripts/nzb-dl.sh add <id> Series               # queue it
./scripts/nzb-dl.sh status                        # rate, queue, health
./scripts/nzb-dl.sh history                       # how past jobs ended
./scripts/nzb-dl.sh remove <job-id>               # GroupDelete, when you grabbed the wrong post
```

Self-check that the parser still works (binsearch changes its markup now and
then): `search` must print rows of `id  size  age  subject`. If it prints `?`
for size/age, the flight-payload parsing broke — the ids are still usable, but
fix the parse before trusting `add`.

## Picking the post — the part that decides success

From best to worst:

1. **A collection post** for the whole season/franchise ("S01", "Batch",
   "Movies \[1080p]"). One id → one job → one folder. `grep -c '<file '` on the
   fetched NZB tells you how many files it really has.
2. **Per-episode posts** with all 27 ids, if no batch survives. Handle them as
   separate jobs.
3. **A pack in a rar set** (`.part01..partNN` + par2) — normal, NZBGet unpacks.
4. Avoid posts whose size is implausible for the runtime (a 200 MB "1080p
   episode" is a re-encode of a worse source), and avoid `parts: n/n` mismatch.

`Health` in `status` is the fraction of articles still available at the
provider: 100% is fresh, 99% is fine, and **anything under ~89.9% is refused
before a byte is downloaded** (see health gate below).

## Requirements
1. Always get English Subtitles!
2. 1080p only!

## Edge cases, all of which have actually bitten

**`Invalid parameter (AddTop)` / `-1` from append.** The jsonrpc `append`
signature is exactly `[NZBFilename, Content, Category, Priority, AddToTop,
AddPaused, DupeKey, DupeScore, DupeMode, PPParameters]`:
- all ten params are required, booleans as JSON `true`/`false`;
- `Content` must be **base64** (raw XML gives
  `Error parsing nzb-file: Start tag expected, '<' not found`);
- the filename must end in `.nzb`, otherwise you get a silent `-1`;
- `-1` carries no reason. `ssh ralph sudo journalctl -u nzbget -n 30` has it.

**Health gate parks the job.** `HealthCheck=park` with a hidden ~89.9% critical
threshold. The journal line is
`[WARNING] Cancelling download and deleting <job> due to health 89.8% below critical 89.9%`.
Options, in order: pick a fresher post; or
`HealthCheck=none` in `/var/lib/nzbget/nzbget.conf` + `sudo systemctl restart nzbget`
(only worth it when par2 redundancy can still repair the hole).

**Dupe check eats the job.** History shows `DELETED/COPY` — NZBGet matched an
existing file. Retry with `--force` (`DupeMode=force`), or accept it as already
present.

**Provider hiccups look like failures.** `Blocking XS News for 10 sec` and
`Could not write to TLS-Socket: … unexpected eof while reading` are transient;
NZBGet reconnects. Sustained blocking plus a flat rate means expired account or
provider outage — check `pass show homelab/xsnews/username` still works.

**par2 can't repair a 10%-eaten post.** `not enough par-blocks, N needed, but M
available` → the job ends `FAILURE/SCAN`/`FAILURE/UNPACK`. Nothing to fix; the
post is gone. Find another.

**Wrong category = invisible download.** Empty category drops the job in
`/srv/media/downloads/complete` and Jellyfin never sees it. Binsearch's own
`Category` names are case-sensitive: `Movies`, `Series`, `Music`, `Software`.

**Library layout after unpack.** The job name (derived from the post subject)
becomes the folder directly under `tv/` or `movies/`. Jellyfin wants
`tv/<Show Name (Year)>/Season 01/<file SxxEyy>.mkv` and
`movies/<Movie Name (Year)>/<file>.mkv`. Loose files and odd folder names often
still match by filename, but a tidy-up is cheap:

```bash
ssh ralph 'ls /srv/media/tv /srv/media/movies'
# then, per show:
ssh ralph 'mv "/srv/media/tv/<job folder>" "/srv/media/tv/Gurren Lagann (2007)"; mkdir -p "/srv/media/tv/Gurren Lagann (2007)/Season 01"; mv /srv/media/tv/Gurren\ Lagann\ \(2007\)/*.mkv "/srv/media/tv/Gurren Lagann (2007)/Season 01/"'
ssh ralph 'sudo chown -R nzbget:jellyfin …; sudo chmod -R 775 …'   # keep Jellyfin able to read
```

**ssh ralph really is the transport.** NZBGet has no LAN listener; do not open
one to make a download "easier". Ralph's `nzbget.conf` is 600 `nzbget:nzbget`
(provider password inside) — read config through
`{"method":"config"}` over jsonrpc instead of `sudo cat`.

**Disk.** `/srv/media` is one 3.6T drive with no redundancy; `df -h /srv/media`
before queueing a 100 GB batch. `UnpackCleanupDisk=yes` deletes the rars after a
successful unpack.

## Done means verified

```bash
./scripts/nzb-dl.sh status      # queue empty, nothing DOWNLOADING
./scripts/nzb-dl.sh history     # last jobs SUCCESS/UNPACK, not FAILURE/*
ssh ralph 'find /srv/media/tv "<Show>" -name "*.mkv" | wc -l'   # episodes present
ssh ralph 'sudo journalctl -u nzbget --since "-2h" | grep -Ei "error|warning" | tail'
```

Report the count that landed, the folder it landed in, and whether Jellyfin
needs a rescan (`sudo systemctl restart jellyfin`, or wait ~30 min).
