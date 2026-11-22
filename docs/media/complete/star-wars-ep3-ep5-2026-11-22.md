# Star Wars Episode III and V missing from Jellyfin — 2026-11-22

## Task

The movie library had Star Wars I, II, IV and VI but not III (Revenge of the
Sith) or V (The Empire Strikes Back).

## What happened

Both had been attempted before and died at the provider — NZBGet history:

| Post | Result |
|---|---|
| `Star.Wars.Episode.III-Revenge...x264-OFT` | `FAILURE/PAR 999` — par2 could not repair the hole |
| `Star.Wars.Episode.V...BluRay.X264-AMIABLE` | `FAILURE/HEALTH 946` |

Re-adding those same ids was silently swallowed by the dupe check
(`DELETED/COPY`), which looks like a success in `history` — the lesson, now in
`.pi/skills/usenet-download/SKILL.md`: **before re-queuing a post, read its old
entry's status; a dupe of a failed post downloads nothing.**

Replacement posts, both health 1000, both with English subtitles (verified with
`ffprobe`), 1080p only:

- III — `Star.Wars.Episode.III.Revenge.of.the.Sith.2005.BluRay.1080p.DDP.5.1.x264-hallowed` (11 GB, `SUCCESS/PAR`)
- V — `Star.Wars.The.Empire.Strikes.Back.Episode.V.1980.MULTI.1080p.DSNP.WEB-DL.DDP5.1.x264-AndreMor` (9.4 GB, `SUCCESS/UNPACK`)

2 MB/s throttle → ~2h50m for the pair, run sequentially by NZBGet.

## Cleanup decision

The library had release-junk folder names — the par2 volume name was used as
the folder name, e.g.
`Star.Wars.4.A.New.Hope.1977.1080p.BluRay.x264-OFT.vol-01.par2_ yEnc  40432 (1-1)/`.
Jellyfin tolerated it but it broke any human or agent looking at the library.

Decision: file every movie as `<Name (Year)>/<Name (Year)>.mkv`, owner
`nzbget:jellyfin`, mode 775 — the layout `docs/media/README.md` already
describes. Applied to all six Star Wars films, Pulp Fiction, and the two
Gurren Lagann movies. Left the loose `.mkv` files at the `movies/` root
(Kokuho, The Shining) and the release-style folders (Barry Lyndon, Full Metal
Jacket, Mulholland Drive, The Animatrix) alone — they already resolve
correctly in Jellyfin, and renaming them only risks losing watch state.

## Verification

- `history`: both jobs `SUCCESS/*`, category `Movies`, health 1000
- `ffprobe`: English subtitle track on both files
- Jellyfin rescan (`POST /jf/Library/Refresh`, `Authorization: MediaBrowser
  Token="…"` — `X-Emby-Token` and `api_key=` both 401 on this build) →
  six rows in `BaseItems` pointing at the new paths, zero ghost paths
  (checked every movie path with `test -e`)
- Item names as Jellyfin/TMDB see them: `Star Wars` (IV), `The Empire Strikes
  Back` (V), `Return of the Jedi` (VI) — TMDB's own titles, not a mismatch.

## Rollback

Re-queue any of the films by id with `./scripts/nzb-dl.sh add <id> Movies`; the
old folders are gone but the mkvs were only moved, all under
`/mnt/storage/media/movies`.
