---
name: usenet-download
description: >
  Download media (or anything) over usenet with an NZB: search NZBGeek, fetch
  the NZB, queue it in NZBGet on Ralph, and check it landed in Jellyfin's
  library. Also the triage when a download succeeded but never appeared in
  Jellyfin (blank category, orphaned in downloads/complete). Use when asked to
  "download X with nzb", "grab X off usenet", "get the rest of series Y", to
  check on or fix a stuck NZBGet job, or when a download was cancelled/parked by
  the health check.
  Triggers: nzb, usenet, nzbget, nzbgeek, geek, binsearch, nzbking,
  "download all of X", par2 repair, health check, "cancelling download", dupe,
  category, unpack, "not in my jellyfin library", "can't see X in jellyfin",
  invisible download, downloads/complete, jellyfin.db.
---

# Downloading with NZB

One script does the whole chain: `~/projects/homelab/scripts/nzb-dl.sh`
(search → fetch → queue on Ralph). This skill is the judgement around it.

## Shape of the pipeline

| Step | Where | Notes |
|---|---|---|
| Search indexer | **Jason/Ralph** (needs WAN) | **NZBGeek is the default** — lifetime sub, API key in `pass show homelab/nzbgeek/apikey`. Fallbacks: `--binsearch` (`binsearch.info`) and `--nzbking` (`nzbking.com`). `nzbindex.com` is client-rendered — its `?q=` search returns no results, don't bother |
| Download the NZB | Jason/Ralph | geek: `api.nzbgeek.info/api?t=get&id=<guid>`; binsearch: a details id = one collection and `-L` is mandatory (308-redirects) |
| Queue it | **Ralph**, NZBGet | `127.0.0.1:6789` only (`AuthorizedIP=127.0.0.1`) → `ssh ralph curl …`, or a plain `curl` when the script is already running on Ralph (it checks `/etc/hostname`). Never the WAN URL |
| Files land | Ralph | `Category=Series` → `/srv/media/tv`, `Movies` → `/srv/media/movies`, `Music`, `Software`. No category → `/srv/media/downloads/complete`, which Jellyfin never sees (the script now refuses an empty one) |
| Play | Jellyfin `http://ralph/jf` | file-watching picks up new files, but `sudo systemctl restart jellyfin.service` is the certain way |

Provider is XS News over TLS (no VPN, no peers — that is qBittorrent's problem).
Measured ceiling: **~4 MB/s** (50 Mbit cap), so 23 GB ≈ 1h40. Say so, don't wait
on it.

## Use it

```bash
cd ~/projects/homelab
./scripts/nzb-dl.sh search "gurren lagann"        # id, size, age, subject (NZBGeek)
./scripts/nzb-dl.sh search "query" --binsearch    # free fallback indexer
./scripts/nzb-dl.sh search "query" --nzbking      # second free fallback
./scripts/nzb-dl.sh add <id> Series --dry-run     # fetch + validate, queue nothing
./scripts/nzb-dl.sh add <id> Series               # queue it
./scripts/nzb-dl.sh status                        # rate, queue, health
./scripts/nzb-dl.sh history                       # how past jobs ended
./scripts/nzb-dl.sh remove <job-id>               # GroupDelete, when you grabbed the wrong post
```

NZBGeek costs nothing per search and answers better. Two things to know:

- **A trial account can search but not download.** `t=get` answers
  `<error code="101" description="Trial Account Only"/>` and the site's own
  download button says "trial limitation". This account is lifetime, so both
  work; if `add` suddenly returns no NZB from geek, check the subscription
  before blaming the post.
- **Geek ANDs every word of the query**, so long queries return 0 with a
  cheerful `total: 0`. Search 3–4 words (`avatar airbender nikt0`), not a
  sentence. `binsearch` is looser and is worth one try when geek says nothing.

The key lives on any release page as the `apikey=` in its NZB link, if it ever
needs re-reading.

Self-check that the parsers still work (both indexers change their markup now
and then): `search` must print rows of `id  size  age  subject`. If it prints
`?` for size/age, the parsing broke — the ids are still usable, but fix the
parse before trusting `add`.

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

**A whole title can be gone, at any age.** Avatar: The Last Airbender (2005)
1080p sits at 85–90% health on *every* post the free indexers show — 8 days old
and 1011 days old, iVy, OFT, FraMeSToR, SubsNoJutsu alike — while Korra in the
same session is 100%. Nothing to pick there: par2 is smaller than the hole
(9.3% vs 10.3%), a fresh post is no healthier, and `HealthCheck=none` just buys
`FAILURE/UNPACK`.
The fix was the indexer, not the post: the free indexers only find the heavily
DMCA'd scene releases, while NZBGeek also lists per-episode re-ups the others
miss — `Avatar.The.Last.Airbender.S01E01…1080p.BluRay.x264-nikt0` (9mo) came
back at health 998/1000 and downloaded clean. So before declaring a title
gone, search geek and look past the obvious names.
Probe with one write-off job (top priority, watch the health column,
`GroupDelete`), don't cycle through a dozen posts. Control check that the
provider is fine: a different show's job at 100%. See
`docs/media/todo/avatar-tla-1080p-2026-11-10.md`.

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

**Wrong category = invisible download.** An empty category drops the job in
`/srv/media/downloads/complete` and Jellyfin never sees it, even though the job
reports `SUCCESS`. `nzb-dl.sh add` refuses an empty one (exit 2) for exactly this
reason — it bit hard once: 26 Cowboy Bebop episodes, 97 GB, invisible
(`docs/media/complete/cowboy-bebop-invisible-in-jellyfin-2026-11-10.md`). If a job
was queued some other way (web UI, raw jsonrpc), nobody checked the category.
Binsearch's own `Category` names are case-sensitive: `Movies`, `Series`, `Music`,
`Software`.

## "I downloaded it but it's not in Jellyfin"

Work down this list; each step is one command and usually ends the search.

```bash
# 1. Did the job actually succeed? Category column blank = it's in downloads/complete.
./scripts/nzb-dl.sh history | head -10

# 2. What is sitting in the folder Jellyfin ignores?
ssh ralph 'du -sh /srv/media/downloads/complete; ls /srv/media/downloads/complete'

# 3. Is it on disk in the library but unindexed / wrongly named?
ssh ralph 'ls /srv/media/tv /srv/media/movies; find /srv/media/tv -iname "*<show>*"'

# 4. Is Jellyfin's database really missing it? (the only proof that matters)
ssh ralph 'sudo cp /var/lib/jellyfin/data/jellyfin.db /tmp/jf.db && sudo chmod 644 /tmp/jf.db'
ssh ralph "sqlite3 /tmp/jf.db \"select Name, Path from BaseItems where Path like '%<show>%' limit 5;\""
ssh ralph "sqlite3 /tmp/jf.db \"select count(*) from BaseItems where Path like '%<show>%';\""
```

Item count check: 1 series + 1 season + N episodes = `N+2` rows. If the rows are
there, it is a client cache — refresh the app; if the folder is there but rows
are not, `sudo systemctl restart jellyfin.service` and re-query.

**Relocate orphans** (the empty category case) without re-downloading. The job
dirs are `nzbget`-owned, so plain `mv` as `andy` fails with `Permission denied` —
use `sudo` throughout, and the episode number comes from the `E<NN>` in the job
name:

```bash
ssh ralph 'set -e
D="/srv/media/tv/Cowboy Bebop (1998)/Season 01"; sudo mkdir -p "$D"
for f in /srv/media/downloads/complete/Cowboy.Bebop.E*/; do
  ep=$(basename "$f" | sed -E "s/^Cowboy\.Bebop\.E([0-9]+)\..*/\1/")
  src=$(sudo find "$f" -maxdepth 1 -name "*.mkv" | head -1)
  sudo mv "$src" "$D/Cowboy Bebop (1998) - S01E${ep}.mkv"
  sudo rmdir "$f"
done
sudo chown -R nzbget:jellyfin "/srv/media/tv/Cowboy Bebop (1998)"
sudo chmod -R 775 "/srv/media/tv/Cowboy Bebop (1998)"'
```

A failed `mv` mid-loop leaves the first episode already renamed — the loop is
idempotent for the rest, just fix the missing one by hand.

**Library layout after unpack.** The job name (derived from the post subject)
becomes the folder directly under `tv/` or `movies/` — so each finished episode
lands in its own folder, and Jellyfin reads every one of those folders as a
*separate series* with the wrong show, wrong year and one episode. Always tidy
before believing anything the library says:

```bash
./scripts/nzb-tidy.sh --dry-run      # what would move
./scripts/nzb-tidy.sh                # every series folder with a year in its name
./scripts/nzb-tidy.sh "Avatar - The Last Airbender (2005)"   # or one show
```

It files each `SxxEyy` video as `tv/<Show (Year)>/Season NN/<Show> - SxxEyy.mkv`,
fixes ownership, and drops the emptied job dir. A show's folder must exist first:
create `tv/<Show Name (Year)>` (name and year from TMDB) if this is a new show —
the year is what stops Jellyfin matching the 2024 live-action Avatar instead of
the 2005 animation. Movies have no `SxxEyy`; file them by hand:

```bash
ssh ralph 'sudo mv "/srv/media/movies/<job folder>/<file>.mkv" "/srv/media/movies/<Movie Name (Year)>/"; sudo chown -R nzbget:jellyfin "/srv/media/movies/<Movie Name (Year)"'
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
./scripts/nzb-dl.sh history     # last jobs SUCCESS/UNPACK, not FAILURE/*, category not blank
ssh ralph 'find /srv/media/tv "<Show>" -name "*.mkv" | wc -l'   # episodes present
ssh ralph "sqlite3 /tmp/jf.db \"select count(*) from BaseItems where Path like '%<Show>%';\""  # N+2 rows in Jellyfin
ssh ralph 'sudo journalctl -u nzbget --since "-2h" | grep -Ei "error|warning" | tail'
```

Report the count that landed, the folder it landed in, and whether Jellyfin
picked it up — prove it in `jellyfin.db`, not by saying "it should scan". If it
did not, `sudo systemctl restart jellyfin.service` and re-query.
