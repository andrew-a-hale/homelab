# Gurren Lagann movies (2026-11-09)

## Task

"Download missing Gurren Lagann movies from nzb."

The series was already complete (27/27 episodes in
`/srv/media/tv/Gurren Lagann S01 (jaaj BD 1080p AV1)`), but both films were
missing. The original movie pack from the first NZB session
(`[bonkai77] Gurren Lagann Movies [1080p] [DUAL-AUDIO] [HEVC] [x265] [10bit]`)
never landed: history shows `FAILURE/HEALTH` at **84.9%** (parked by the
health gate, then retried) and then `FAILURE/SCAN` — the post is eaten and par2
couldn't repair it. Nothing to fix there; it needed different posts.

## What was done

Two `[jaaj]` posts, same group as the working series release, queued as
`Movies` → `/srv/media/movies`:

| Film | Job | Size | Health |
|---|---|---|---|
| Childhood's End (2008) | 36 | 2.09 GB (11 files) | 100% |
| The Lights in the Sky Are Stars (2009) | 37 | 4.14 GB (12 files) | 100% |

6.2 GB total at the measured ~4.4 MB/s, so ~25 min of downloading. Both were
moved to the top of the queue (`editqueue GroupMoveTop`) so they don't sit
behind the 100 GB Cowboy Bebop batch — that batch is bulk, these were asked for.

## Decisions and why

- **`jaaj` over the alternatives.** Verified with `ffprobe` on the existing
  series files that the jaaj release carries **English audio and English
  subtitle tracks** — the two hard requirements (1080p, English subs) are met by
  keeping the same encode family, so the films match the show instead of
  introducing a third source with different styling. `SubsNoJutsu` was the
  fallback (`S00E03`/`S00E04`, 1080p x265, 21 days old) but it is a different
  group, x265 rather than AV1, and it labels the films as specials.
- **Rejected the 720p, VOSTFR, and 2160p REMUX posts** on the stated rules —
  the first two miss 1080p, and a 79 GB remux is 12x the size of everything else
  in the request on a drive with no redundancy.
- **`nzb-dl.sh` now runs on Ralph.** The script's doc header said "runs on Jason
  (or any box with curl+python3+ssh)", but from Ralph every `ssh ralph curl …`
  died with `Host key verification failed` — Ralph does not trust its own key.
  `rpc()` now checks `/etc/hostname` and, when it matches `RALPH_HOST`, calls
  `curl 127.0.0.1:6789` in-process. The loopback-only posture is unchanged;
  nothing new listens.

Also worth knowing: NZBGet's move command is `GroupMoveTop`, **not**
`GroupTop` — the latter returns `Invalid action`, which cost one round trip.

## Verified

```
./scripts/nzb-dl.sh status   # both jobs QUEUED at top, health 1000
./scripts/nzb-dl.sh history  # earlier bonkai77 movie pack: FAILURE/HEALTH, FAILURE/SCAN
```
