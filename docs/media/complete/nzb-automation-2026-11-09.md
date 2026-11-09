# NZB downloading, automated (2026-11-09)

## Task

"Download all Gurren Lagann episodes and movies with nzb" — the first real use
of the usenet box (see [`nzbget-parallel-2026-11-09.md`](nzbget-parallel-2026-11-09.md)),
and then "create a skill to automate downloading with nzb" once the manual path
was known.

## What was done

Two NZBs, found on `binsearch.info` and pushed straight into NZBGet on Ralph:

| Post | Category | Size | Files |
|---|---|---|---|
| `[jaaj] Gurren Lagann S01 (2007) (BD 1080p AV1 OPUS)` — all 27 episodes | `Series` → `/srv/media/tv` | 11.9 GB | 39 (27 rar + par2) |
| `[bonkai77] Gurren Lagann Movies [1080p] [DUAL-AUDIO] [HEVC] [x265] [10bit]` — both films | `Movies` → `/srv/media/movies` | 11.3 GB | 43 |

Health at queue time: 100% and 99.4%, so both pass the park-gate. Measured
~4 MB/s (the 50 Mbit provider cap), ~1h40 for the pair.

Then `scripts/nzb-dl.sh` (search / add / status / history / remove) and the
agent skill `~/.pi/agent/skills/usenet-download/SKILL.md`.

## Decisions and why

- **Binsearch as the script's indexer, nzbking as the fallback.** Binsearch
  answers `?q=` with a full result list in its Next.js flight payload — parseable
  after decoding each `self.__next_f.push([1,"…"])` string literal. `nzbindex.com`
  renders results client-side and returns an empty payload for `?q=`, so it is
  dropped from the README table rather than kept as decoration. nzbking stays
  because its markup is plain HTML and its `/nzb:<id>/` endpoint is trivial.
- **The script lives in the repo, the skill points at it.** One copy of the
  logic, documented next to the thing it operates on; the skill carries the
  judgement (which post to pick, what the failures mean), not a second
  implementation.
- **jsonrpc instead of uploading through the WebUI.** `/nzb/` is nginx +
  basic-auth + loopback-only; `ssh ralph curl 127.0.0.1:6789` is the same door
  without a password prompt in a script, and it keeps the "nothing listens on
  the LAN" posture intact for automation too.
- **Job names from the post subject.** The job name becomes the folder Jellyfin
  scans, so `nzb-dl-<id>` was replaced by the subject (stripped of
  `[01/39] - "…" yEnc` and the first file's `.part01`). Still imperfect — the
  folder is not `<Show (Year)>/Season 01` — but a rename beats an opaque id.
- **`--force` rather than disabling the dupe check.** `DupeCheck=yes` is what
  stops the same release being pulled twice; the flag overrides it once, per job.

## Traps recorded (all hit during this task)

1. binsearch `322/308`-redirects `/` and `/?q=` → `-L` and `/search?q=`.
2. A search row's id is the *file* id; the details page carries the collection
   id in a hidden `id` input, and `/nzb?id=<collection id>` returns the whole
   post. `/nzb?<id>=on&<id2>=on` picks individual files.
3. NZBGet `append` needs all ten params, **base64** `Content`, and a filename
   ending `.nzb`. Each mistake gives a different useless error: raw XML →
   `Start tag expected, '<' not found`; missing params → `Invalid parameter
   (AddTop)`; no `.nzb` suffix → silent `-1`.
4. `-1` never says why: `sudo journalctl -u nzbget -n 30`.
5. `HealthCheck=park`'s ~89.9% critical threshold is hidden but real; it refused
   the earlier Twin Peaks test post. `HealthCheck=none` is the override.
6. `editqueue GroupDelete` takes `(Command, Offset, Text, IDs)` — `Text` must be
   a string, `[]` errors.
7. `nzbindex.com` search is client-rendered: `?q=` returns no results.

## Left open

- The unpacked layout still needs a rename pass before Jellyfin is happy with
  `<Show>/Season 01`; the skill has the commands, nothing automates it.
- Throughput, par2 repair and unrar on a rar post are still unverified for these
  two jobs — they were queued 2026-11-09 and finish in ~1h40.
