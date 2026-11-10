# Cowboy Bebop downloaded but not in Jellyfin (2026-11-10)

## Symptom

26 Cowboy Bebop episodes were downloaded overnight (all `SUCCESS/PAR`, 97 GB) but
the show never appeared in Jellyfin. `ls /srv/media/tv` had no Cowboy Bebop.

## Cause

The 26 jobs were queued with **no category** (`nzb-dl.sh add <id>` without the
`Series` argument). NZBGet's empty category lands the job in
`/srv/media/downloads/complete`, which Jellyfin's library (`/srv/media/movies`,
`/srv/media/tv`) never scans. The downloads were complete and healthy the whole
time — just invisible. Confirmed in `nzb-dl.sh history`: the category column was
blank for exactly those 26 rows.

## Fix

1. Moved each `Cowboy.Bebop.E<NN>.*.mkv` into Jellyfin's layout:
   `/srv/media/tv/Cowboy Bebop (1998)/Season 01/Cowboy Bebop (1998) - S01E<NN>.mkv`,
   `chown nzbget:jellyfin`, `chmod 775`, and removed the empty job dirs.
2. Restarted `jellyfin.service`; verified in `jellyfin.db` — 28 items (series,
   season, 26 episodes).
3. Hardened the cause: `scripts/nzb-dl.sh add` now **requires** a category and
   exits 2 without one, instead of silently queueing into the invisible folder.

Episodes are D-Z0N3 FLAC dual-ish releases: Japanese FLAC 5.1 + AC-3 commentary,
English soft subs (SRT) embedded — meets the 1080p + English subs requirement.

## Why

A silent, valid-looking download into a directory no scanner watches cost a night
and 97 GB of "where is it". Requiring the category is one line and turns a silent
invisible download into an immediate error. Check the category column in
`nzb-dl.sh history` first next time a download "didn't arrive".
