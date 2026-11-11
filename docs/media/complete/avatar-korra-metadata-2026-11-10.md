# Korra and The Last Airbender showed the wrong metadata (2026-11-10)

**Decision:** file every finished usenet episode into
`tv/<Show (Year)>/Season NN/<Show> - SxxEyy.mkv` with
[`scripts/nzb-tidy.sh`](../../../scripts/nzb-tidy.sh), and always name the series
folder with its year. Nothing was wrong with the downloaded files or with
Jellyfin's metadata providers.

## What it looked like

Jellyfin listed **24 series** for 7 shows:

- 16 copies of `Avatar: The Last Airbender`, all `ProductionYear 2024` — the
  live-action Netflix show, not the 2005 animation.
- 4 copies of `The Legend of Korra`, one per season, with the episodes matching
  against nothing.
- 171 episode rows, most of them against paths that no longer made sense.

## Why

NZBGet's series `DestDir` is `/srv/media/tv` with `AppendCategoryDir=no`, so the
job's folder name — the post subject, e.g.
`Avatar.The.Last.Airbender.S01E01.The.Boy.in.the.Iceberg.1080p.BluRay.x264-nikt0.vol-01.par2_ yEnc (1-28)`
— becomes a folder directly in the library. Jellyfin's series layout treats every
top-level folder in a TV library as a series, so each single-episode download was
its own series, named after the release and matched by search to whatever show
that text most looked like (for Avatar: the 2024 one). Korra's season packs hit
the same thing one level down: four folder-per-season "series".

This is the "rename pass" already flagged as a ceiling in
[`nzb-automation-2026-11-09.md`](nzb-automation-2026-11-09.md); it was being done
by hand, per show, and so it was being skipped.

## What was done

1. Moved all 68 files into the layout Jellyfin parses:
   `Avatar - The Last Airbender (2005)/Season 0N/Avatar - The Last Airbender - SxxEyy.mkv`
   (17) and `The Legend of Korra (2012)/Season 0N/The Legend of Korra - SxxEyy.mkv`
   (52), `chown nzbget:jellyfin`, `chmod 664`/`775`, and deleted the 20 emptied
   release folders.
2. Restarted Jellyfin; the scan dropped the 20 bogus series and re-filed the
   episodes. One stale episode row (the live-action match, path already moved)
   did not clear on its own and was deleted through the API
   (`DELETE /jf/Items/<id>`, token = the `ApiKeys` row).
3. Verified in `/var/lib/jellyfin/data/jellyfin.db`: one `Avatar: The Last
   Airbender` **2005** (17 episodes), one `The Legend of Korra` **2012** (52),
   with real titles and aired-order numbering, e.g. Korra S03E13 *Venom of the
   Red Lotus*, S04E13 *The Last Stand*.

Filenames carry no episode titles on purpose — Jellyfin takes titles, air dates
and images from TMDB by `SxxEyy`; the redundant title text in a release name is
what made the folders ambiguous in the first place.

## Why a script and not a smarter NZBGet config

NZBGet always creates a per-job folder; removing it means a post-processing
extension script and risking par2/unpack sharing a directory between concurrent
jobs, against a working pipeline. `scripts/nzb-tidy.sh` is ~70 lines, works on
Jason (hops to Ralph) or Ralph, has `--dry-run`, and refuses to guess a show's
year — the caller names the series folder once, from TMDB.

## Ceilings

- It only files shows whose folder already exists with a year in the name
  (`… (YYYY)`). A new show still needs one `mkdir` naming it. `Cyberpunk
  Edgerunners` and `Twin Peaks` have no year and so are never tidied — they are
  already correct.
- It is manual. A batch of 45 queued episodes is not tidied until someone runs
  it, and each untidied episode is a visible bogus series in the meantime.
  Hooking it into NZBGet's post-processing (or a timer) would remove that
  stutter; not done until it actually annoys us.

## Verify

```bash
ssh ralph "sudo sqlite3 -readonly /var/lib/jellyfin/data/jellyfin.db \
  \"select s.Name,s.ProductionYear,count(distinct e.Path) from BaseItems e
    join BaseItems s on s.Id=e.SeriesId
    where e.Type='MediaBrowser.Controller.Entities.TV.Episode' group by s.Id;\""
```

One row per real show, episode count equal to `find /srv/media/tv/<Show> -name '*.mkv' | wc -l`.

## After the batch finished (same day)

The remaining ~45 Avatar episodes landed over the next few hours, each as its own
release folder; one `./scripts/nzb-tidy.sh` filed 23 more and emptied every job
dir, so `/srv/media/tv` now holds six real series and nothing else. That left 20
episodes missing on the download side, not the layout side.

## The nikt0 gaps came back corrupt (2026-11-11)

Re-queued all 20 from the same `1080p BluRay x264-nikt0` posts, every one from
NZBGeek. **All 20 failed `FAILURE/PAR`**, reproducibly, with identical symptoms:

```
Par: 1 file(s) exist but are damaged
Par: 75 out of 106 data blocks available
Par: Repair is not possible. You need 31 more recovery blocks
```

- `health 1000` (every article exists) and `FailedArticles 0` (NZBGet took every
  article, all yEnc CRCs good) — but ~30% of the assembled blocks fail par2.
- Not truncation or a sparse file: the mkv is the right size, no zero blocks, no
  duplicated blocks; `ffmpeg` shows real container and h264 damage from ~1 MB in.
- Not an NZBGet or disk problem: the same pipeline downloaded 41 episodes of the
  same release group successfully, and a `1080p BluRay x264-hallowed` REPACK of
  S01E04 downloaded and verified first try.

So those specific nikt0 posts hold damaged data on XS News — worth remembering
that `health` measures article *availability*, never article *content*.

## Complete: 61 of 61 (2026-11-11)

Three sources, and the library is whole:

| Source | Episodes | Note |
|---|---|---|
| `1080p BluRay x264-nikt0` | 42 | the original Geek batch, ~1.3 GB each |
| `BluRay 1080p AAC 2.0 x264-hallowed` | 1 | S01E04, the first successful alternate |
| `1080p BluRay x264-OFT` | 18 | every other gap, ~1.1 GB each, one post per episode |

Two dead ends on the way: the `x264-CiNEFiLE` posts found on binsearch all parked
at `FAILURE/HEALTH 898` (binsearch's older posts are ~10% short of articles; the
health gate refuses them before a byte is downloaded), and 19 OFT jobs were the
first to verify clean on the first attempt. Key/`pass` note: NZBGeek's API key is
behind `pinentry-tty`, so a headless sweep only works while the key is cached
(`default-cache-ttl` 600 s) and then needs `pass show homelab/nzbgeek/apikey` run
by hand in a terminal.

Also cleaned up: 40 GB of `downloads/inter` leftovers from the failed Avatar
attempts, all of which had already been re-downloaded from a working source.

Final state in `jellyfin.db`: `Avatar: The Last Airbender` **2005**, 61 episodes
on disk and 61 in the library, one series, real titles and aired-order numbering.
Same session, the same pipeline delivered *Ramayana: The Legend of Prince Rama*
(1993, DVDRip x264-HANDJOB, English + Hindi 5.1, English subs) into
`movies/Ramayana - The Legend of Prince Rama (1993)/` — movies carry no `SxxEyy`,
so they are filed by hand.
